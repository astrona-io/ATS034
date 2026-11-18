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

S, O = 'starfleet-034-040-02-03', 'outpost-034-040-02-03'
PROBE = 'http://probe.' + S + '.svc.cluster.local/'
HOSTS = ('probe', 'probe.' + S, 'probe.' + S + '.svc', 'probe.' + S + '.svc.cluster.local', '*.' + S + '.svc.cluster.local', '*.svc.cluster.local', '*.cluster.local', '*')


def namespace_strict():
    policy = get('peerauthentication', 'namespace-strict', S)
    assert not policy['spec'].get('selector'), 'namespace-strict must cover the whole namespace, so it has no selector'
    assert mode(policy) == 'STRICT', 'namespace-strict must set mtls.mode STRICT'
    for other in items('peerauthentication', S):
        if other['metadata']['name'] != 'namespace-strict' and selects(other, {'app': 'probe'}):
            assert mode(other) == 'STRICT', 'The policy ' + other['metadata']['name'] + ' weakens STRICT for the probe pods'


def client_tls_fixed():
    for namespace in (S, O, 'istio-system'):
        for rule in items('destinationrule', namespace):
            if rule['spec'].get('host') in HOSTS:
                policy = rule['spec'].get('trafficPolicy') or {}
                settings = [policy.get('tls')] + [item.get('tls') for item in policy.get('portLevelSettings') or []]
                for tls in settings:
                    tls_mode = (tls or {}).get('mode')
                    assert tls_mode in (None, 'ISTIO_MUTUAL'), 'The DestinationRule ' + namespace + '/' + rule['metadata']['name'] + ' still sets tls.mode ' + str(tls_mode) + ' for the probe Service'


if wants('namespace-strict'):
    namespace_strict()
    require_sidecars(S, ['probe'], [], [(O, 'drifter')])
    expect_reset(O, 'drifter', PROBE)
if wants('client-tls-fixed'):
    client_tls_fixed()
if wants('shuttle-mtls'):
    namespace_strict()
    require_sidecars(S, ['probe'], ['shuttle'])
    expect_reply(S, 'shuttle', PROBE)
