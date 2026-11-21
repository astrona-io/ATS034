# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json


def has_proxy(pod):
    """Istio 1.30 on Kubernetes 1.35 injects istio-proxy as a native sidecar (an init container)."""
    spec = pod['spec']
    return any(item['name'] == 'istio-proxy' for item in spec.get('containers', []) + spec.get('initContainers', []))


def request(namespace, pod, url):
    """Send one bounded HTTP request with busybox wget from the pod's client container."""
    result = command(['kubectl', '-n', namespace, 'exec', pod, '-c', 'client', '--', 'wget', '-q', '-T', '3', '-O-', url], success=False)
    return result.returncode, (result.stdout + result.stderr).strip()


def expect_reply(namespace, pod, url):
    code, output = request(namespace, pod, url)
    assert code == 0 and 'version=' in output, f'{namespace}/{pod} must get a reply from {url} but got: {output or "no output"}'
    return output


def expect_forbidden(namespace, pod, url):
    code, output = request(namespace, pod, url)
    assert code != 0 and '403' in output, f'{namespace}/{pod} must get HTTP 403 from {url} but got: {output or "no output"}'


def items(kind, namespace):
    return json.loads(kubectl('-n', namespace, 'get', kind, '-o', 'json'))['items']


def selects(spec, labels):
    selector = (spec.get('selector') or {}).get('matchLabels') or {}
    return all(labels.get(key) == value for key, value in selector.items())


def deployment_pods(namespace, name):
    pods = items('pod', namespace)
    found = [pod for pod in pods if pod['metadata'].get('labels', {}).get('app') == name and pod['status'].get('phase') == 'Running']
    assert found, f'The {name} pods in {namespace} must be running'
    return found


def require_sidecars(namespace, deployments, clients):
    for name in deployments:
        assert all(has_proxy(pod) for pod in deployment_pods(namespace, name)), f'The {name} pods must keep their istio-proxy sidecar'
    for name in clients:
        assert has_proxy(get('pod', name, namespace)), f'The {name} pod must keep its istio-proxy sidecar'


def service_account(namespace, pod, expected):
    actual = get('pod', pod, namespace)['spec'].get('serviceAccountName', 'default')
    assert actual == expected, f'The {pod} pod must keep the ServiceAccount {expected}, not {actual}'


S = 'starfleet-034-040-02-04'
PROBE = 'http://probe.' + S + '.svc.cluster.local/'
SHUTTLE = 'cluster.local/ns/' + S + '/sa/shuttle'


def allow_policy():
    """The policy the team wrote must stay: action ALLOW, a selector for the probe pods, and rules."""
    spec = get('authorizationpolicy', 'probe-allow-shuttle', S)['spec']
    assert spec.get('action', 'ALLOW') == 'ALLOW', 'probe-allow-shuttle must keep the action ALLOW'
    assert (spec.get('selector') or {}).get('matchLabels'), 'probe-allow-shuttle must keep its selector for the probe pods'
    assert selects(spec, {'app': 'probe'}), 'The selector of probe-allow-shuttle must match the probe pods (app: probe)'
    assert spec.get('rules'), 'probe-allow-shuttle needs its rule; an ALLOW policy without rules denies every request'
    return spec


def principal_exact():
    for rule in allow_policy()['rules']:
        sources = rule.get('from') or []
        assert sources, 'Every rule of probe-allow-shuttle must name the allowed caller in from.source'
        for entry in sources:
            source = entry.get('source') or {}
            assert source.get('principals') == [SHUTTLE], 'Each source must list only the principal ' + SHUTTLE + ', not ' + str(source.get('principals'))
            extra = sorted(key for key in source if key != 'principals')
            assert not extra, 'Each source must match only by principal; remove: ' + ', '.join(extra)


# Guards for every outcome: the workloads keep their sidecars and ServiceAccounts.
require_sidecars(S, ['probe'], ['shuttle', 'drifter'])
service_account(S, 'shuttle', 'shuttle')
service_account(S, 'drifter', 'default')

if wants('shuttle-allowed'):
    allow_policy()
    expect_reply(S, 'shuttle', PROBE)
if wants('drifter-denied'):
    allow_policy()
    expect_reply(S, 'shuttle', PROBE)
    expect_forbidden(S, 'drifter', PROBE)
if wants('principal-exact'):
    principal_exact()
