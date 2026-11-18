# Checks that read the kube-apiserver process and the raw etcd data on the
# lab VM. check.py runs this file with NODE, node_exec(), command(),
# kubectl(), get() and wants() already defined.
import base64

NS = 'starfleet-034-020-01-03'
CONFIG_PATH = '/etc/kubernetes/enc/enc.yaml'
ENCRYPTED = (b'k8s:enc:aescbc:v1:', b'k8s:enc:secretbox:v1:')
# etcdctl is not installed on the node; it runs inside the etcd container.
# The value is binary, so it is base64-encoded before it leaves the VM shell.
ETCDCTL = ('crictl exec "$(crictl ps --name etcd -q)" etcdctl'
           ' --cacert=/etc/kubernetes/pki/etcd/ca.crt'
           ' --cert=/etc/kubernetes/pki/etcd/server.crt'
           ' --key=/etc/kubernetes/pki/etcd/server.key'
           ' get --print-value-only ')


def etcd_value(namespace, name):
    key = '/registry/secrets/' + namespace + '/' + name
    result = node_exec(NODE, 'sh', '-c', ETCDCTL + key + ' | base64 -w0', success=False)
    raw = base64.b64decode(result.stdout.strip() or '')
    assert raw, 'Could not read ' + key + ' from etcd'
    return raw


def process_arguments(program):
    found = node_exec(NODE, 'pgrep', '-n', '-f', '^(/[^ ]*/)?' + program + '( |$)', success=False).stdout.strip()
    assert found, program + ' is not running'
    raw = node_exec(NODE, 'cat', '/proc/' + found + '/cmdline', success=False).stdout
    return [item for item in raw.split('\0') if item]


def assert_encrypted(name):
    raw = etcd_value(NS, name)
    assert raw.startswith(ENCRYPTED), 'Secret ' + name + ' is stored without aescbc or secretbox encryption in etcd'
    assert b'disposable' not in raw, 'Secret ' + name + ' still shows its plain value in etcd'


if wants('encryption-enabled'):
    arguments = process_arguments('kube-apiserver')
    values = [item.split('=', 1)[1] for item in arguments if item.startswith('--encryption-provider-config=')]
    assert values and values[-1] == CONFIG_PATH, 'kube-apiserver must run with --encryption-provider-config=' + CONFIG_PATH
    stat = node_exec(NODE, 'stat', '-c', '%a %U', CONFIG_PATH, success=False)
    assert stat.returncode == 0, CONFIG_PATH + ' is missing on the node'
    mode, owner = stat.stdout.split()
    assert int(mode, 8) & 0o177 == 0 and owner == 'root', CONFIG_PATH + ' must be owned by root with mode 600 or stricter'
    # Proof by a real write: a new Secret must reach etcd encrypted.
    kubectl('-n', NS, 'delete', 'secret', 'grader-encryption-check', '--ignore-not-found')
    kubectl('-n', NS, 'create', 'secret', 'generic', 'grader-encryption-check', '--from-literal=value=disposable-grader')
    try:
        assert_encrypted('grader-encryption-check')
    finally:
        kubectl('-n', NS, 'delete', 'secret', 'grader-encryption-check', '--ignore-not-found')

if wants('existing-secrets-encrypted'):
    for name, key, value in (('probe-credentials', 'password', 'disposable-probe-password'), ('scout-token', 'token', 'disposable-scout-token')):
        assert_encrypted(name)
        data = get('secret', name, NS).get('data') or {}
        assert base64.b64decode(data.get(key, '')).decode() == value, 'Secret ' + name + ' must still return its value through the API'
