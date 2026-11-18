# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
UNTRUSTED, TRUSTED = 'untrusted-034-030-02-03', 'trusted-034-030-02-03'
IMAGE = 'docker.io/library/busybox:1.37.0'


def dry_run_pod(namespace, runtime_class=None):
    """Send a Pod create request through admission without storing it."""
    args = ['kubectl', '-n', namespace, 'run', 'admission-check', '--image=' + IMAGE, '--dry-run=server', '-o', 'name']
    if runtime_class:
        args.append('--overrides={"spec":{"runtimeClassName":"' + runtime_class + '"}}')
    return command(args, success=False)


if wants('require-sandbox'):
    policy = get('validatingadmissionpolicy', 'require-sandbox', namespace=None)
    assert any('CREATE' in rule.get('operations', []) and 'pods' in rule.get('resources', [])
               for rule in policy['spec'].get('matchConstraints', {}).get('resourceRules', [])), 'The policy require-sandbox must match CREATE requests for pods'
    binding = get('validatingadmissionpolicybinding', 'require-sandbox-untrusted', namespace=None)
    assert binding['spec'].get('policyName') == 'require-sandbox', 'The binding require-sandbox-untrusted must name the policy require-sandbox'
    assert 'Deny' in binding['spec'].get('validationActions', []), 'The binding require-sandbox-untrusted must use the validation action Deny'
    denied = dry_run_pod(UNTRUSTED)
    output = denied.stdout + denied.stderr
    assert denied.returncode != 0 and 'require-sandbox' in output and 'denied request' in output, \
        'A new Pod without runtimeClassName in ' + UNTRUSTED + ' must be denied by require-sandbox'
    assert 'Pods must set runtimeClassName sandboxed' in output, 'The denial must show the message: Pods must set runtimeClassName sandboxed'
    allowed = dry_run_pod(UNTRUSTED, 'sandboxed')
    assert allowed.returncode == 0, 'A new Pod with runtimeClassName sandboxed in ' + UNTRUSTED + ' must be admitted: ' + allowed.stderr.strip()
    other = dry_run_pod(TRUSTED)
    assert other.returncode == 0, 'A Pod without runtimeClassName in ' + TRUSTED + ' must still be admitted: ' + other.stderr.strip()

if wants('job-runner-sandboxed'):
    pod = get('pod', 'job-runner', UNTRUSTED)
    spec, status = pod['spec'], pod.get('status', {})
    assert spec.get('runtimeClassName') == 'sandboxed', 'Pod job-runner must run with runtimeClassName: sandboxed'
    assert spec['containers'][0]['image'] == IMAGE, 'Pod job-runner must keep the image ' + IMAGE
    assert status.get('phase') == 'Running' and any(item['type'] == 'Ready' and item['status'] == 'True'
                                                    for item in status.get('conditions', [])), 'Pod job-runner must be Running and Ready'
