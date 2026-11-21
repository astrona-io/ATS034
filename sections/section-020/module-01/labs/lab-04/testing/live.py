# Checks that read the encryption configuration, the kube-apiserver process
# and the raw etcd data on the lab VM. check.py runs this file with NODE,
# node_exec(), command(), kubectl(), get() and wants() already defined.
import base64
import hashlib
import json
import time

import yaml

NS = 'starfleet-034-020-01-04'
CONFIG_PATH = '/etc/kubernetes/enc/enc.yaml'
# bootstrap/setup.sh writes the SHA-256 of the key1 value here, so the
# graders can recognize key1 under any name without knowing the key.
KEY1_HASH_PATH = '/var/lib/astrona-lab/key1.sha256'
KEY2_PREFIX = b'k8s:enc:aescbc:v1:key2:'
LAB_SECRETS = (
    ('probe-credentials', 'password', 'disposable-probe-password'),
    ('scout-token', 'token', 'disposable-scout-token'),
    ('bridge-api-key', 'key', 'disposable-bridge-key'),
)
# etcdctl is not installed on the node; it runs inside the etcd container.
ETCDCTL = ('crictl exec "$(crictl ps --name etcd -q)" etcdctl'
           ' --cacert=/etc/kubernetes/pki/etcd/ca.crt'
           ' --cert=/etc/kubernetes/pki/etcd/server.crt'
           ' --key=/etc/kubernetes/pki/etcd/server.key')


def node_text(*args):
    result = node_exec(NODE, *args, success=False)
    assert result.returncode == 0, 'Could not read ' + args[-1] + ' on the node'
    return result.stdout


def key1_hash():
    return node_text('cat', KEY1_HASH_PATH).strip()


def secrets_config():
    """The provider list for the resource secrets in the EncryptionConfiguration."""
    try:
        config = yaml.safe_load(node_text('cat', CONFIG_PATH)) or {}
    except yaml.YAMLError:
        raise AssertionError(CONFIG_PATH + ' is not valid YAML')
    for entry in config.get('resources') or []:
        if 'secrets' in (entry.get('resources') or []):
            return entry.get('providers') or []
    raise AssertionError(CONFIG_PATH + ' has no entry for the resource secrets')


def provider_keys(providers):
    keys = []
    for provider in providers:
        for settings in provider.values():
            if isinstance(settings, dict):
                keys.extend(settings.get('keys') or [])
    return keys


def value_hash(key):
    return hashlib.sha256(str(key.get('secret', '')).encode()).hexdigest()


def apiserver_pid():
    found = node_exec(NODE, 'pgrep', '-n', '-f', '^(/[^ ]*/)?kube-apiserver( |$)', success=False).stdout.strip()
    assert found, 'kube-apiserver is not running'
    return found


def assert_apiserver_uses_config():
    raw = node_exec(NODE, 'cat', '/proc/' + apiserver_pid() + '/cmdline', success=False).stdout
    values = [item.split('=', 1)[1] for item in raw.split('\0') if item.startswith('--encryption-provider-config=')]
    assert values and values[-1] == CONFIG_PATH, 'kube-apiserver must run with --encryption-provider-config=' + CONFIG_PATH
    stat = node_exec(NODE, 'stat', '-c', '%a %U', CONFIG_PATH, success=False)
    assert stat.returncode == 0, CONFIG_PATH + ' is missing on the node'
    mode, owner = stat.stdout.split()
    assert int(mode, 8) & 0o177 == 0 and owner == 'root', CONFIG_PATH + ' must be owned by root with mode 600 or stricter'


def etcd_secrets():
    """Every Secret in etcd as {key: stored value}, read without the API server."""
    result = node_exec(NODE, 'sh', '-c', ETCDCTL + ' get /registry/secrets/ --prefix -w json', success=False)
    assert result.returncode == 0, 'Could not read the Secrets from etcd'
    stored = {}
    for item in json.loads(result.stdout).get('kvs') or []:
        stored[base64.b64decode(item['key']).decode()] = base64.b64decode(item.get('value', ''))
    assert stored, 'etcd holds no Secrets'
    return stored


if wants('key2-first'):
    assert_apiserver_uses_config()
    providers = secrets_config()
    first = providers[0] if providers else {}
    assert 'aescbc' in first, 'The first provider for secrets must be aescbc'
    keys = (first.get('aescbc') or {}).get('keys') or []
    assert keys and keys[0].get('name') == 'key2', 'The first aescbc key must be named key2'
    try:
        length = len(base64.b64decode(str(keys[0].get('secret', '')), validate=True))
    except ValueError:
        length = 0
    assert length == 32, 'key2 must be a base64-encoded 32-byte key'
    assert value_hash(keys[0]) != key1_hash(), 'key2 must be a new key, not the value of key1'
    # Proof by a real write: the running kube-apiserver must encrypt with key2.
    kubectl('-n', NS, 'delete', 'secret', 'grader-rotation-check', '--ignore-not-found')
    kubectl('-n', NS, 'create', 'secret', 'generic', 'grader-rotation-check', '--from-literal=value=disposable-grader')
    try:
        stored = etcd_secrets().get('/registry/secrets/' + NS + '/grader-rotation-check', b'')
        assert stored.startswith(KEY2_PREFIX), 'A new Secret is not stored with key2; restart the kube-apiserver after you change ' + CONFIG_PATH
    finally:
        kubectl('-n', NS, 'delete', 'secret', 'grader-rotation-check', '--ignore-not-found')

if wants('secrets-use-key2'):
    stored = etcd_secrets()
    for name, _, _ in LAB_SECRETS:
        assert '/registry/secrets/' + NS + '/' + name in stored, 'Secret ' + name + ' is missing in etcd'
    old = sorted(key for key, value in stored.items() if not value.startswith(KEY2_PREFIX))
    assert not old, str(len(old)) + ' Secrets in etcd are not stored with key2, for example ' + old[0]

if wants('key1-removed'):
    assert_apiserver_uses_config()
    keys = provider_keys(secrets_config())
    assert not any(key.get('name') == 'key1' for key in keys), CONFIG_PATH + ' still has a key named key1'
    assert not any(value_hash(key) == key1_hash() for key in keys), CONFIG_PATH + ' still holds the value of key1'
    # The kube-apiserver reads the file only at start, so it must have started
    # after the last change to the file.
    elapsed = int(node_text('ps', '-o', 'etimes=', '-p', apiserver_pid()).strip())
    changed = int(node_text('stat', '-c', '%Y', CONFIG_PATH).strip())
    assert time.time() - elapsed >= changed - 1, 'kube-apiserver has not been restarted since the last change to ' + CONFIG_PATH
    for name, key, value in LAB_SECRETS:
        data = get('secret', name, NS).get('data') or {}
        assert base64.b64decode(data.get(key, '')).decode() == value, 'Secret ' + name + ' must still return its value through the API'
