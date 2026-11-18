# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here. The guards in
# requirements.json already proved that the reader Pod exists and is Ready.


def in_reader(*args):
    """Run a command in the reader Pod and return the finished process."""
    return command(['kubectl', '-n', NAMESPACE, 'exec', 'reader', '--', *args], success=False)


def status_fields():
    result = in_reader('cat', '/proc/1/status')
    assert result.returncode == 0, 'Could not read /proc/1/status in reader'
    fields = {}
    for line in result.stdout.splitlines():
        key, _, value = line.partition(':')
        fields[key.strip()] = value.strip()
    return fields


if wants('runs-as-user-1000'):
    result = in_reader('id', '-u')
    assert result.returncode == 0 and result.stdout.strip() == '1000', 'The process in reader must run as user ID 1000, found: ' + (result.stdout.strip() or result.stderr.strip())
if wants('kernel-settings'):
    fields = status_fields()
    assert fields.get('NoNewPrivs') == '1', 'NoNewPrivs must be 1: set allowPrivilegeEscalation to false'
    assert fields.get('Seccomp') == '2', 'Seccomp must be 2: select the RuntimeDefault seccomp profile'
    assert fields.get('CapEff') == '0000000000000000', 'CapEff must be all zeros: drop ALL capabilities'
if wants('root-read-only'):
    mode = in_reader('stat', '-c', '%a', '/tmp')
    assert mode.returncode == 0 and mode.stdout.strip() == '1777', '/tmp must stay the image directory with mode 1777; do not mount a volume there'
    written = in_reader('touch', '/tmp/grader-check')
    assert written.returncode != 0 and 'Read-only file system' in written.stderr, 'Writing /tmp/grader-check must fail with Read-only file system'
if wants('scratch-writable'):
    written = in_reader('sh', '-c', 'echo ok > /scratch/grader-check && cat /scratch/grader-check')
    assert written.returncode == 0 and written.stdout.strip() == 'ok', 'User 1000 must be able to write to /scratch'
