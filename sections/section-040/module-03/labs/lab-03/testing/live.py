# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here. The checks run
# commands inside the cilium-agent containers, which use the network namespace
# of their node, so no container engine access is needed. No check prints
# command output that could hold key material.
import json
import re

S = 'starfleet-034-040-03-03'
PROBE = 'http://probe.' + S + '.svc.cluster.local:8080/'


def nodes():
    return json.loads(kubectl('get', 'nodes', '-o', 'json'))['items']


def stale_node():
    """The setup restarts only the agent on the control-plane node, so the agent on the other node is stale."""
    workers = [node['metadata']['name'] for node in nodes() if 'node-role.kubernetes.io/control-plane' not in node['metadata'].get('labels', {})]
    assert len(workers) == 1, 'The lab expects exactly one worker node'
    return workers[0]


def agents():
    pods = json.loads(kubectl('-n', 'kube-system', 'get', 'pods', '-l', 'k8s-app=cilium', '-o', 'json'))['items']
    running = [pod for pod in pods if pod['status'].get('phase') == 'Running' and not pod['metadata'].get('deletionTimestamp')]
    names = {node['metadata']['name'] for node in nodes()}
    covered = {pod['spec'].get('nodeName') for pod in running}
    assert names <= covered, 'A running Cilium agent pod must exist on every node'
    return running


def agent_exec(pod, *args):
    result = command(['kubectl', '-n', 'kube-system', 'exec', pod['metadata']['name'], '-c', 'cilium-agent', '--', *args], success=False)
    assert result.returncode == 0, 'The command ' + ' '.join(args[:3]) + ' failed in the Cilium agent on node ' + pod['spec']['nodeName']
    return result.stdout


def encrypt_status(pod):
    return agent_exec(pod, 'cilium-dbg', 'encrypt', 'status')


def expect_probe_reply():
    result = command(['kubectl', '-n', S, 'exec', 'shuttle', '-c', 'client', '--', 'wget', '-q', '-T', '3', '-O-', PROBE], success=False)
    output = (result.stdout + result.stderr).strip()
    assert result.returncode == 0 and 'probe-reply' in output, 'The shuttle pod must get probe-reply from ' + PROBE + ' but got: ' + (output or 'no output')


if wants('stale-node-recorded'):
    diagnosis = get('configmap', 'encryption-diagnosis', S)
    recorded = (diagnosis.get('data') or {}).get('node', '').strip()
    assert recorded, 'The ConfigMap encryption-diagnosis must have the key node'
    assert recorded == stale_node(), 'The ConfigMap encryption-diagnosis names ' + recorded + ', which is not the node whose agent still reported Encryption: Disabled'
if wants('wireguard-on-every-agent'):
    for pod in agents():
        node = pod['spec']['nodeName']
        assert re.search(r'Encryption:\s*Wireguard', encrypt_status(pod)), 'The Cilium agent on ' + node + ' does not report Encryption: Wireguard'
        link = json.loads(agent_exec(pod, 'ip', '-j', '-d', 'link', 'show', 'dev', 'cilium_wg0'))
        assert link and link[0].get('linkinfo', {}).get('info_kind') == 'wireguard', 'Node ' + node + ' has no WireGuard interface cilium_wg0'
if wants('wireguard-peers'):
    running = agents()
    expected = len(nodes()) - 1
    for pod in running:
        node = pod['spec']['nodeName']
        status = encrypt_status(pod)
        assert re.search(r'Encryption:\s*Wireguard', status), 'The Cilium agent on ' + node + ' does not report Encryption: Wireguard'
        peers = re.search(r'Number of peers:\s*(\d+)', status)
        assert peers and int(peers.group(1)) == expected, 'The Cilium agent on ' + node + ' must have ' + str(expected) + ' WireGuard peer(s), one for each other node'
    expect_probe_reply()
