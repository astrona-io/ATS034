# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here. The checks run
# commands inside the cilium-agent containers, which use the network namespace
# of their node, so no container engine access is needed. No check prints
# command output that could hold key material.
import base64
import hashlib
import json
import re


def agents():
    pods = json.loads(kubectl('-n', 'kube-system', 'get', 'pods', '-l', 'k8s-app=cilium', '-o', 'json'))['items']
    running = [pod for pod in pods if pod['status'].get('phase') == 'Running' and not pod['metadata'].get('deletionTimestamp')]
    nodes = {pod['spec'].get('nodeName') for pod in running}
    assert len(nodes) >= 2, 'A running Cilium agent pod must exist on both nodes'
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

S = 'starfleet-034-040-03-01'
PROBE = 'http://probe.' + S + '.svc.cluster.local:8080/'

def wireguard_on_every_agent():
    for pod in agents():
        status = encrypt_status(pod)
        node = pod['spec']['nodeName']
        assert re.search(r'Encryption:\s*Wireguard', status), 'The Cilium agent on ' + node + ' does not report Encryption: Wireguard'
        assert re.search(r'Number of peers:\s*1\b', status), 'The Cilium agent on ' + node + ' does not have exactly one WireGuard peer'


def wg_tx_bytes(pod):
    link = json.loads(agent_exec(pod, 'ip', '-j', '-s', 'link', 'show', 'dev', 'cilium_wg0'))
    return link[0]['stats64']['tx']['bytes']


if wants('wireguard-enabled'):
    wireguard_on_every_agent()
if wants('cross-node-encrypted'):
    running = agents()
    for pod in running:
        wg_tx_bytes(pod)
    shuttle_node = get('pod', 'shuttle', S)['spec']['nodeName']
    probe_node = get('pod', 'probe', S)['spec']['nodeName']
    assert shuttle_node != probe_node, 'The shuttle and probe pods must run on different nodes'
    agent = next(pod for pod in running if pod['spec']['nodeName'] == shuttle_node)
    before = wg_tx_bytes(agent)
    expect_probe_reply()
    after = wg_tx_bytes(agent)
    assert after > before, 'The request from shuttle did not leave its node through cilium_wg0'
