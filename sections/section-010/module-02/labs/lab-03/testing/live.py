# Live checks for this lab. check.py runs this file inside the lab VM with
# NODE, node_exec(), kubectl(), get(), command() and wants() already defined.


def scout_exec(*args):
    return command(['kubectl', '-n', NAMESPACE, 'exec', 'scout', '--', *args], success=False)


def profile_field(field):
    """A profile can be set on the Pod or on the container; the container value wins."""
    pod = get('pod', 'scout')
    container = next(item for item in pod['spec']['containers'] if item['name'] == 'scout')
    own = (container.get('securityContext') or {}).get(field)
    return own if own is not None else (pod['spec'].get('securityContext') or {}).get(field)


def failure_text(result):
    return (result.stdout + result.stderr).lower()


if wants('mkdir-blocked'):
    profile = profile_field('seccompProfile') or {}
    assert profile.get('type') == 'Localhost' and profile.get('localhostProfile') == 'profiles/block-mkdir.json', \
        'scout must use the Localhost seccomp profile profiles/block-mkdir.json'
    status = scout_exec('grep', 'Seccomp:', '/proc/1/status')
    assert status.stdout.split()[-1:] == ['2'], 'The process of scout must run with a seccomp filter (Seccomp: 2)'
    # The AppArmor profile denies only /tmp, so a directory at / shows the seccomp result.
    made = scout_exec('sh', '-c', 'mkdir /grader-check && rmdir /grader-check')
    assert made.returncode != 0 and 'operation not permitted' in failure_text(made), \
        'mkdir in scout must fail with Operation not permitted'

if wants('tmp-write-denied'):
    profile = profile_field('appArmorProfile') or {}
    assert profile.get('type') == 'Localhost' and profile.get('localhostProfile') == 'k8s-deny-tmp-write', \
        'scout must use the Localhost AppArmor profile k8s-deny-tmp-write'
    label = scout_exec('cat', '/proc/1/attr/current').stdout.strip()
    assert label == 'k8s-deny-tmp-write (enforce)', 'The process of scout must run under k8s-deny-tmp-write in enforce mode, not ' + repr(label)
    written = scout_exec('sh', '-c', 'echo test > /tmp/grader-check')
    assert written.returncode != 0 and 'permission denied' in failure_text(written), \
        'Writing a file under /tmp in scout must fail with Permission denied'
