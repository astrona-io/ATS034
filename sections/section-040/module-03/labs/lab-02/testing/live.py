# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get(), command(), node_exec() and WORKER are available
# here. Most checks run commands inside the cilium-agent containers, which use
# the network namespace of their node. The wire check runs a short packet
# capture with python3 on the worker node (node_exec, through the container
# engine). No check prints command output that could hold key material.
import base64
import hashlib
import json
import re
import threading
import time


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


# Reads every frame on eth0 of the node for the given number of seconds and
# prints one JSON line: the number of frames, whether the text probe-reply was
# seen in any frame, and the count of ESP packets (IP protocol 50) per SPI.
# The SPI is the first 4 bytes after the IPv4 header of an ESP packet.
CAPTURE = """
import json, socket, sys, time
sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
sock.bind(('eth0', 0))
sock.settimeout(0.5)
end = time.time() + float(sys.argv[1])
spis, frames, plain = {}, 0, False
while time.time() < end:
    try:
        frame = sock.recv(65535)
    except socket.timeout:
        continue
    frames += 1
    plain = plain or b'probe-reply' in frame
    if len(frame) < 38 or frame[12:14] != b'\\x08\\x00' or frame[23] != 50:
        continue
    start = 14 + (frame[14] & 15) * 4
    spi = int.from_bytes(frame[start:start + 4], 'big')
    spis[spi] = spis.get(spi, 0) + 1
print(json.dumps({'frames': frames, 'plain': plain, 'esp': spis}))
"""
REQUESTS = 'i=0; while [ $i -lt 8 ]; do wget -q -T 2 -O- ' + PROBE + '; i=$((i+1)); sleep 0.5; done'


def capture_cross_node_traffic():
    """Capture on the worker node while shuttle sends requests to probe."""
    result = []
    capture = threading.Thread(target=lambda: result.append(node_exec(WORKER, 'python3', '-c', CAPTURE, '9', success=False)))
    capture.start()
    time.sleep(1.5)
    requests = command(['kubectl', '-n', S, 'exec', 'shuttle', '-c', 'client', '--', 'sh', '-c', REQUESTS], success=False)
    capture.join(timeout=25)
    assert requests.stdout.count('probe-reply') >= 4, 'The shuttle pod did not get probe-reply from ' + PROBE + ' during the capture'
    assert result and result[0].returncode == 0, 'The packet capture on node ' + WORKER + ' failed'
    return json.loads(result[0].stdout.strip().splitlines()[-1])


if wants('wire-uses-new-spi'):
    secret_key()
    shuttle_node = get('pod', 'shuttle', S)['spec']['nodeName']
    probe_node = get('pod', 'probe', S)['spec']['nodeName']
    assert shuttle_node != probe_node, 'The shuttle and probe pods must run on different nodes'
    seen = capture_cross_node_traffic()
    spis = {int(value): count for value, count in seen['esp'].items()}
    assert not seen['plain'], 'The text probe-reply is readable on eth0 of ' + WORKER + ': the traffic between the nodes is not encrypted'
    assert spis, 'No ESP packets were seen on eth0 of ' + WORKER + ' while shuttle sent requests to probe'
    assert 3 not in spis, 'ESP packets between the nodes still carry the starting SPI 3'
    spi = rotated_spi()
    old = sorted(value for value in spis if value != spi)
    assert spi in spis, 'The ESP packets between the nodes carry SPI ' + ', '.join(map(str, old)) + ', not the new SPI ' + str(spi)
    assert not old, 'ESP packets between the nodes still carry SPI ' + ', '.join(map(str, old)) + ' next to the new SPI ' + str(spi)
