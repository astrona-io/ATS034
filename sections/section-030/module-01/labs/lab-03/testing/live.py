# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
TENANT, STARFLEET = 'tenant-a-034-030-01-03', 'starfleet-034-030-01-03'
TOKEN_DIRECTORY = '/var/run/secrets/kubernetes.io/serviceaccount'


def fetch(namespace, pod, address):
    """One HTTP request with busybox wget and a 3 second timeout."""
    return command(['kubectl', '-n', namespace, 'exec', pod, '--', 'wget', '-q', '-T', '3', '-O-', 'http://' + address + '/'], success=False)


def expect_open(namespace, pod, address, app):
    result = fetch(namespace, pod, address)
    assert result.returncode == 0 and 'app=' + app in result.stdout, f'{namespace}/{pod} must reach {app} at {address} but got: ' + (result.stderr.strip().splitlines() or ['no output'])[-1]


def expect_timeout(namespace, pod, address, app):
    result = fetch(namespace, pod, address)
    assert result.returncode != 0 and 'timed out' in result.stderr, f'{namespace}/{pod} must time out to {app} at {address}'


def beacon_address():
    address = get('pod', 'beacon', STARFLEET)['status'].get('podIP')
    assert address, 'The beacon Pod has no IP address'
    return address + ':8080'


def worker_ready():
    pod = get('pod', 'worker', TENANT)
    assert pod['status'].get('phase') == 'Running', 'The worker Pod must be running'
    return pod


def policy(name):
    return get('networkpolicy', name, TENANT)['spec']


if wants('default-deny'):
    spec = policy('default-deny')
    assert spec.get('podSelector') in ({}, None) or not (spec['podSelector'].get('matchLabels') or spec['podSelector'].get('matchExpressions')), 'default-deny must select every Pod with an empty podSelector'
    assert sorted(spec.get('policyTypes', [])) == ['Egress', 'Ingress'], 'default-deny must cover Ingress and Egress'
    # The API server drops an empty list, so a missing field and [] are the same.
    assert not spec.get('ingress') and not spec.get('egress'), 'default-deny must not allow any traffic'
    worker_ready()
    expect_open(STARFLEET, 'shuttle', beacon_address(), 'beacon')
    expect_timeout(TENANT, 'worker', beacon_address(), 'beacon')

if wants('probe-allowed'):
    spec = policy('allow-probe')
    assert 'Egress' in spec.get('policyTypes', []), 'allow-probe must be an egress policy'
    for rule in spec.get('egress') or []:
        assert rule.get('to'), 'An egress rule without "to" allows every address'
        assert rule.get('ports'), 'An egress rule without ports allows every port'
        for peer in rule['to']:
            assert 'ipBlock' not in peer, 'Select the probe Pods by label, not by address'
            assert peer.get('podSelector', {}).get('matchLabels', {}).get('app') == 'probe', 'Each peer must select the Pods with app=probe'
    worker_ready()
    service = get('service', 'probe', STARFLEET)['spec']['clusterIP']
    expect_open(TENANT, 'worker', service, 'probe')
    expect_timeout(TENANT, 'worker', beacon_address(), 'beacon')

if wants('no-token'):
    account = get('serviceaccount', 'worker', TENANT)
    assert account.get('automountServiceAccountToken') is False, 'Set automountServiceAccountToken: false on the ServiceAccount worker'
    pod = worker_ready()
    assert pod['spec'].get('serviceAccountName') == 'worker', 'The worker Pod must keep the ServiceAccount worker'
    result = command(['kubectl', '-n', TENANT, 'exec', 'worker', '--', 'ls', TOKEN_DIRECTORY], success=False)
    assert result.returncode != 0 and 'No such file' in result.stderr, 'The worker Pod still has the token directory; recreate the Pod'
