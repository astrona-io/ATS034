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


def expect_reset(namespace, pod, url):
    code, output = request(namespace, pod, url)
    assert code != 0 and 'reset by peer' in output.lower(), f'{namespace}/{pod} must fail with a connection reset to {url} but got: {output or "no output"}'


def items(kind, namespace):
    return json.loads(kubectl('-n', namespace, 'get', kind, '-o', 'json'))['items']


def mode(policy):
    return (policy['spec'].get('mtls') or {}).get('mode')


def selects(policy, labels):
    selector = (policy['spec'].get('selector') or {}).get('matchLabels') or {}
    return all(labels.get(key) == value for key, value in selector.items())


def deployment_pods(namespace, name):
    pods = items('pod', namespace)
    found = [pod for pod in pods if pod['metadata'].get('labels', {}).get('app') == name and pod['status'].get('phase') == 'Running']
    assert found, f'The {name} pods in {namespace} must be running'
    return found


def require_sidecars(namespace, deployments, clients, plain=()):
    for name in deployments:
        assert all(has_proxy(pod) for pod in deployment_pods(namespace, name)), f'The {name} pods must keep their istio-proxy sidecar'
    for name in clients:
        assert has_proxy(get('pod', name, namespace)), f'The {name} pod must keep its istio-proxy sidecar'
    for namespace_name, name in plain:
        assert not has_proxy(get('pod', name, namespace_name)), f'The {name} pod must stay without a sidecar'

S = 'starfleet-034-040-01-02'
PROBE = 'http://probe.' + S + '.svc.cluster.local/'
SHUTTLE = 'cluster.local/ns/starfleet-034-040-01-02/sa/shuttle'


def allow_policy():
    policy = get('authorizationpolicy', 'probe-allow-shuttle', S)
    spec = policy['spec']
    assert spec.get('action', 'ALLOW') == 'ALLOW', 'The policy action must be ALLOW'
    assert (spec.get('selector') or {}).get('matchLabels'), 'The policy must select the probe pods with a selector'
    assert selects(policy, {'app': 'probe'}), 'The policy selector must match the probe pods (app: probe)'
    assert not selects(policy, {'app': 'shuttle'}), 'The policy must select only the probe pods'
    rules = spec.get('rules') or []
    assert rules, 'The policy needs a rule; an ALLOW policy without rules denies every request'
    for rule in rules:
        sources = rule.get('from') or []
        assert sources, 'Every rule must name the allowed caller in from.source'
        for entry in sources:
            principals = (entry.get('source') or {}).get('principals') or []
            assert principals == [SHUTTLE], 'Each source must list only the principal ' + SHUTTLE
    return policy


if wants('allow-policy'):
    allow_policy()
if wants('shuttle-allowed'):
    allow_policy()
    require_sidecars(S, ['probe'], ['shuttle'])
    expect_reply(S, 'shuttle', PROBE)
if wants('tender-denied'):
    allow_policy()
    require_sidecars(S, ['probe'], ['tender'])
    code, output = request(S, 'tender', PROBE)
    assert code != 0 and '403' in output, 'The tender pod must get HTTP 403 from the probe sidecar but got: ' + (output or 'no output')
