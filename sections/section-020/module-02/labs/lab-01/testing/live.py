# Live checks for the image pull Secret lab. check.py runs this file with
# kubectl(), get(), command(), contains() and wants() defined.
import base64
import json

NS = 'starfleet-034-020-02-01'
REGISTRY = 'registry.example.test'


def registry_entry():
    secret = get('secret', 'registry-pull', NS)
    encoded = (secret.get('data') or {}).get('.dockerconfigjson')
    assert encoded, 'Secret registry-pull has no .dockerconfigjson key'
    document = json.loads(base64.b64decode(encoded))
    entry = (document.get('auths') or {}).get(REGISTRY)
    assert entry, 'The .dockerconfigjson has no entry for ' + REGISTRY
    return entry


def credential_pair(entry):
    """kubectl writes both auth and username/password; accept either form."""
    if entry.get('auth'):
        return base64.b64decode(entry['auth']).decode()
    return '{}:{}'.format(entry.get('username', ''), entry.get('password', ''))


if wants('pull-secret'):
    assert credential_pair(registry_entry()) == 'practice:disposable-pull', \
        'The entry for ' + REGISTRY + ' must hold the user practice and the password disposable-pull'

if wants('serviceaccount-pull'):
    account = get('serviceaccount', 'puller', NS)
    names = [item.get('name') for item in account.get('imagePullSecrets') or []]
    assert 'registry-pull' in names, 'ServiceAccount puller must list registry-pull in imagePullSecrets'

if wants('pod-receives-pull-secret'):
    pod = get('pod', 'pull-check', NS)
    names = [item.get('name') for item in pod['spec'].get('imagePullSecrets') or []]
    assert 'registry-pull' in names, 'Pod pull-check has no registry-pull in spec.imagePullSecrets'
