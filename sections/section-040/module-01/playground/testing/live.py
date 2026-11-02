pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
assert len(pods)==2 and all(any(container['name']=='istio-proxy' for container in pod['spec']['containers']) for pod in pods), 'Require actual injected application proxies'
assert any(container['name']=='istio-proxy' for container in get('pod','shuttle')['spec']['containers']), 'Require an injected client'
assert not any(container['name']=='istio-proxy' for container in get('pod','drifter',namespace='outpost')['spec']['containers']), 'Preserve the plaintext negative client'
