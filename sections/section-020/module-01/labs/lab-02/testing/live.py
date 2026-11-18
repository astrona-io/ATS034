# Live checks for the rotation of Secret practice-token. check.py runs this
# file with kubectl(), get(), command(), contains() and wants() defined.
import base64
import time

NS = 'starfleet-034-020-01-02'
NEW_VALUE = 'disposable-v2'


def secret_rotated():
    data = get('secret', 'practice-token', NS).get('data') or {}
    return base64.b64decode(data.get('token', '')).decode() == NEW_VALUE


def starting_uid(pod):
    return get('configmap', 'rotation-start', NS)['data'][pod + '-uid']


def compare_in(pod, expression):
    """Compare a value inside the container; the credential never leaves the Pod."""
    script = 'test "' + expression + '" = ' + NEW_VALUE + ' && echo new || echo old'
    result = command(['kubectl', '-n', NS, 'exec', pod, '--', 'sh', '-c', script], success=False)
    assert result.returncode == 0, 'Could not run a command in ' + pod + ': ' + (result.stderr.strip().splitlines() or ['no output'])[-1]
    return result.stdout.strip()


if wants('file-refreshed'):
    assert secret_rotated(), 'Rotate Secret practice-token to the new value first'
    pod = get('pod', 'file-reader', NS)
    assert pod['metadata']['uid'] == starting_uid('file-reader'), 'file-reader was deleted or recreated; the original Pod must keep running'
    volumes = {item['name'] for item in pod['spec'].get('volumes') or [] if (item.get('secret') or {}).get('secretName') == 'practice-token'}
    assert any(item['name'] in volumes and item['mountPath'].rstrip('/') == '/credentials' for item in pod['spec']['containers'][0].get('volumeMounts') or []), 'file-reader must still mount practice-token at /credentials'
    # The kubelet refreshes a Secret volume on its next sync, which can take
    # over a minute. Wait for it, at most 90 seconds.
    deadline = time.monotonic() + 90
    while compare_in('file-reader', '$(cat /credentials/token)') != 'new':
        assert time.monotonic() < deadline, '/credentials/token in file-reader still holds the old value after 90 seconds'
        time.sleep(5)

if wants('environment-refreshed'):
    assert secret_rotated(), 'Rotate Secret practice-token to the new value first'
    pod = get('pod', 'env-reader', NS)
    assert pod['metadata']['uid'] != starting_uid('env-reader'), 'env-reader is still the original Pod; a running container keeps the old environment'
    reference = {'name': 'PRACTICE_TOKEN', 'valueFrom': {'secretKeyRef': {'name': 'practice-token', 'key': 'token'}}}
    assert any(contains(item, reference) for item in pod['spec']['containers'][0].get('env') or []), 'PRACTICE_TOKEN in env-reader must still come from the key token of Secret practice-token'
    assert compare_in('env-reader', '$PRACTICE_TOKEN') == 'new', 'PRACTICE_TOKEN in env-reader does not hold the new value'
