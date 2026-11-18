# Live checks for the two delivery paths of Pod token-reader. check.py runs
# this file with kubectl(), get(), command(), contains() and wants() defined.
NS = 'starfleet-034-020-01-01'


def reader_container():
    pod = get('pod', 'token-reader', NS)
    containers = pod['spec']['containers']
    assert len(containers) == 1, 'Pod token-reader must have one container'
    return pod, containers[0]


def run_in_reader(script):
    """Run a shell line in the container; the credential never leaves the Pod."""
    result = command(['kubectl', '-n', NS, 'exec', 'token-reader', '--', 'sh', '-c', script], success=False)
    assert result.returncode == 0, 'Could not run a command in token-reader: ' + (result.stderr.strip().splitlines() or ['no output'])[-1]
    return result.stdout.strip()


if wants('environment-delivery'):
    pod, container = reader_container()
    reference = {'name': 'PRACTICE_TOKEN', 'valueFrom': {'secretKeyRef': {'name': 'practice-token', 'key': 'token'}}}
    assert any(contains(item, reference) for item in container.get('env') or []), 'PRACTICE_TOKEN must come from the key token of Secret practice-token'
    assert run_in_reader('test "$PRACTICE_TOKEN" = disposable-v1 && echo match || echo different') == 'match', 'PRACTICE_TOKEN in the running container does not hold the Secret value'

if wants('volume-delivery'):
    pod, container = reader_container()
    volumes = {item['name'] for item in pod['spec'].get('volumes') or [] if (item.get('secret') or {}).get('secretName') == 'practice-token'}
    mounts = [item for item in container.get('volumeMounts') or [] if item['name'] in volumes and item['mountPath'].rstrip('/') == '/credentials']
    assert mounts, 'Mount a Secret volume from practice-token at /credentials'
    assert run_in_reader('test "$(cat /credentials/token)" = disposable-v1 && echo match || echo different') == 'match', '/credentials/token does not hold the Secret value'
    mode = run_in_reader('stat -L -c %a /credentials/token')
    assert mode == '400', '/credentials/token has mode ' + mode + '; it must be 400 (read for the owner only)'
