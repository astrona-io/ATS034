import base64
import re
values = json.loads(get('configmap', 'cilium-values', namespace='kube-system')['data']['values.json'])
encryption = values.get('encryption', {})
assert encryption.get('enabled') is True, 'Encryption must be enabled in the values'
assert encryption.get('type') == 'ipsec', 'The encryption type must be ipsec'
assert encryption.get('ipsec', {}).get('secretName') == 'cilium-ipsec-keys', 'The values must name the key Secret'
secret = get('secret', 'cilium-ipsec-keys', namespace='kube-system')
line = base64.b64decode(secret['data']['keys']).decode().strip()
assert re.fullmatch(r'[0-9]+\+? rfc4106\(gcm\(aes\)\) [0-9a-f]{40} 128', line), 'The key line must have the SPI, algorithm, 40 hexadecimal characters and 128'
