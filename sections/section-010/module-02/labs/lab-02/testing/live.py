# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.


def courier_exec(*args):
    return command(['kubectl', '-n', NAMESPACE, 'exec', 'courier', '--', *args], success=False)


def status_fields():
    result = courier_exec('cat', '/proc/1/status')
    assert result.returncode == 0, 'Could not read /proc/1/status in courier'
    fields = {}
    for line in result.stdout.splitlines():
        key, _, value = line.partition(':')
        fields[key.strip()] = value.strip()
    return fields


if wants('capabilities-dropped'):
    fields = status_fields()
    assert fields.get('Uid', '').split()[:1] == ['0'], 'courier must still run as user ID 0, as the task says'
    assert fields.get('CapEff') == '0000000000000000', 'CapEff of courier must be all zeros'
    assert fields.get('CapBnd') == '0000000000000000', 'CapBnd of courier must be all zeros'
    # Root without CAP_CHOWN cannot give a file to another user.
    changed = courier_exec('sh', '-c', 'touch /tmp/grader-owned && chown 1000 /tmp/grader-owned')
    assert changed.returncode != 0 and 'operation not permitted' in (changed.stdout + changed.stderr).lower(), \
        'chown as root must fail with Operation not permitted'

if wants('no-new-privileges'):
    assert status_fields().get('NoNewPrivs') == '1', 'NoNewPrivs of courier must be 1'
