def proxied(pod):
    """Istio injects istio-proxy as a native sidecar (an init container that restarts always) on newer Kubernetes."""
    spec = pod['spec']
    return any(c['name'] == 'istio-proxy' for c in spec.get('containers', [])) or any(
        c['name'] == 'istio-proxy' and c.get('restartPolicy') == 'Always' for c in spec.get('initContainers', []))


pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
assert len(pods)==2 and all(proxied(pod) for pod in pods), 'Require actual injected application proxies'
assert proxied(get('pod','shuttle')), 'Require an injected client'
assert not proxied(get('pod','drifter',namespace='outpost')), 'Preserve the plaintext negative client'
