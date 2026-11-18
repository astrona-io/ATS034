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

S = 'starfleet-034-040-03-02'
PROBE = 'http://probe.' + S + '.svc.cluster.local:8080/'

def secret_key():
    """Parse the key line. Never print it: assertion messages name fields, not values."""
    secret = get('secret', 'cilium-ipsec-keys', 'kube-system')
    line = base64.b64decode(secret['data']['keys']).decode().strip()
    fields = line.split()
    assert len(fields) == 4, 'The keys value must have four fields: SPI, algorithm, key and length'
    spi, algorithm, key, length = fields
    assert re.fullmatch(r'[0-9]+\+?', spi), 'The first field must be a number, optionally followed by +'
    assert algorithm == 'rfc4106(gcm(aes))', 'The second field must be rfc4106(gcm(aes))'
    assert re.fullmatch(r'(0x)?[0-9a-fA-F]{40}', key), 'The third field must be 40 hexadecimal characters'
    assert length == '128', 'The fourth field must be 128'
    return int(spi.rstrip('+')), key.lower().removeprefix('0x')


def rotated_spi():
    spi, key = secret_key()
    assert spi > 3, 'The Secret still uses SPI ' + str(spi) + '; a rotation needs a higher SPI than 3'
    start = get('configmap', 'lab-start-key-fingerprint', 'kube-system')['data']['sha256']
    assert hashlib.sha256(key.encode()).hexdigest() != start, 'The Secret has a new SPI but still the starting key value'
    return spi


if wants('key-rotated'):
    rotated_spi()
if wants('agents-use-new-key'):
    spi = rotated_spi()
    for pod in agents():
        node = pod['spec']['nodeName']
        status = encrypt_status(pod)
        assert re.search(r'Encryption:\s*IPsec', status), 'The Cilium agent on ' + node + ' does not report Encryption: IPsec'
        assert re.search(r'Errors:\s*0\b', status), 'The Cilium agent on ' + node + ' reports IPsec errors'
        spis = {int(value, 16) for value in re.findall(r'spi (0x[0-9a-f]+)', agent_exec(pod, 'ip', 'xfrm', 'state'))}
        assert spi in spis, 'Node ' + node + ' has no IPsec security association with the new SPI ' + str(spi) + ' yet'
    expect_probe_reply()
