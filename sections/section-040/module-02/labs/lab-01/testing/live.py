pods=json.loads(kubectl('-n','starfleet-034-040-02-01','get','pods','-l','app in (probe,legacy)','-o','json'))['items']
assert len(pods)==3 and all(any(container['name']=='istio-proxy' for container in pod['spec']['containers']) for pod in pods), 'Require actual injected application proxies'
assert any(container['name']=='istio-proxy' for container in get('pod','shuttle')['spec']['containers']), 'Require an injected client'
assert not any(container['name']=='istio-proxy' for container in get('pod','drifter',namespace='outpost-034-040-02-01')['spec']['containers']), 'Preserve the plaintext negative client'
if wants('namespace-strict'):
    namespace_policy=get('peerauthentication','namespace-strict')
    assert 'selector' not in namespace_policy['spec'], 'The strict policy must cover the whole namespace'
