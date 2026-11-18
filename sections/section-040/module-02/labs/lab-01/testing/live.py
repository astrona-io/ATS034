def proxied(pod):
    """Istio injects istio-proxy as a native sidecar (an init container that restarts always) on newer Kubernetes."""
    spec = pod['spec']
    return any(c['name'] == 'istio-proxy' for c in spec.get('containers', [])) or any(
        c['name'] == 'istio-proxy' and c.get('restartPolicy') == 'Always' for c in spec.get('initContainers', []))


pods=json.loads(kubectl('-n','starfleet-034-040-02-01','get','pods','-l','app in (probe,legacy)','-o','json'))['items']
assert len(pods)==3 and all(proxied(pod) for pod in pods), 'Require actual injected application proxies'
assert proxied(get('pod','shuttle')), 'Require an injected client'
assert not proxied(get('pod','drifter',namespace='outpost-034-040-02-01')), 'Preserve the plaintext negative client'
if wants('namespace-strict'):
    namespace_policy=get('peerauthentication','namespace-strict')
    assert 'selector' not in namespace_policy['spec'], 'The strict policy must cover the whole namespace'
