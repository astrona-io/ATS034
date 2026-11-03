import base64
pods = json.loads(kubectl('-n', 'starfleet', 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
assert len(pods) == 2 and all(any(container['name'] == 'istio-proxy' for container in pod['spec']['containers']) for pod in pods), 'Require actual injected application proxies'
for client in ('shuttle', 'tender'):
    assert any(container['name'] == 'istio-proxy' for container in get('pod', client)['spec']['containers']), 'Require injected clients'
assert not any(container['name'] == 'istio-proxy' for container in get('pod', 'drifter', namespace='outpost')['spec']['containers']), 'Preserve the plaintext negative client'
policy = get('authorizationpolicy', 'probe-allow-shuttle')['spec']
assert policy.get('action', 'ALLOW') == 'ALLOW', 'The policy must be an ALLOW policy'
principals = [principal for rule in policy.get('rules', []) for source in rule.get('from', []) for principal in source.get('source', {}).get('principals', [])]
assert principals == ['cluster.local/ns/starfleet/sa/shuttle'], 'Allow only the shuttle identity'
values = json.loads(get('configmap', 'cilium-values', namespace='kube-system')['data']['values.json'])
encryption = values.get('encryption', {})
assert encryption.get('enabled') is True and encryption.get('type') == 'wireguard' and encryption.get('nodeEncryption') is True, 'Set the WireGuard values with node encryption'
