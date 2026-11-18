# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json


def scanner_pods():
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=scanner', '-o', 'json'))['items']
    running = [item['metadata']['name'] for item in pods
               if item['status'].get('phase') == 'Running' and not item['metadata'].get('deletionTimestamp')]
    assert len(running) == 2, 'Two scanner Pods must be running, found ' + str(len(running))
    return running


def status_fields(pod):
    result = command(['kubectl', '-n', NAMESPACE, 'exec', pod, '--', 'cat', '/proc/1/status'], success=False)
    assert result.returncode == 0, 'Could not read /proc/1/status in ' + pod
    fields = {}
    for line in result.stdout.splitlines():
        key, _, value = line.partition(':')
        fields[key.strip()] = value.strip()
    return fields


if wants('pods-restricted'):
    for pod in scanner_pods():
        fields = status_fields(pod)
        assert fields.get('Uid', '').split()[:1] == ['1000'], pod + ' must run as user ID 1000'
        assert fields.get('NoNewPrivs') == '1', pod + ': NoNewPrivs must be 1'
        assert fields.get('Seccomp') == '2', pod + ': Seccomp must be 2'
        assert fields.get('CapEff') == '0000000000000000', pod + ': CapEff must be all zeros'
