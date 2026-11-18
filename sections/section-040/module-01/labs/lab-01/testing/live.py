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

S, O = 'starfleet-034-040-01-01', 'outpost-034-040-01-01'
PROBE = 'http://probe.' + S + '.svc.cluster.local/'


def strict_for_namespace():
    """STRICT from a policy in the namespace or from the mesh-wide policy in istio-system, and nothing weaker in the namespace."""
    namespace_policies = [policy for policy in items('peerauthentication', S) if not policy['spec'].get('selector')]
    mesh_policies = [policy for policy in items('peerauthentication', 'istio-system') if not policy['spec'].get('selector')]
    effective = namespace_policies or mesh_policies
    assert effective and mode(effective[0]) == 'STRICT', 'No PeerAuthentication without a selector sets STRICT for ' + S + ' (in ' + S + ' or mesh-wide in istio-system)'
    for policy in items('peerauthentication', S):
        if policy['spec'].get('selector') and selects(policy, {'app': 'probe'}):
            assert mode(policy) in (None, 'UNSET', 'STRICT'), 'The workload policy ' + policy['metadata']['name'] + ' weakens STRICT for the probe pods'
            for port, setting in (policy['spec'].get('portLevelMtls') or {}).items():
                assert setting.get('mode') in ('STRICT', 'UNSET'), 'The workload policy ' + policy['metadata']['name'] + ' weakens STRICT on port ' + str(port)


if wants('strict-policy'):
    strict_for_namespace()
if wants('shuttle-allowed'):
    strict_for_namespace()
    require_sidecars(S, ['probe'], ['shuttle'])
    expect_reply(S, 'shuttle', PROBE)
if wants('drifter-denied'):
    strict_for_namespace()
    require_sidecars(S, ['probe'], [], [(O, 'drifter')])
    expect_reset(O, 'drifter', PROBE)
