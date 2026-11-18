# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json

TENANT_A, TENANT_B = 'tenant-a-034-030-01-01', 'tenant-b-034-030-01-01'
FORBIDDEN = 'forbidden'


def as_alice(*args):
    """Send one request to the API server as the user alice (impersonation)."""
    return command(['kubectl', '--as', 'alice', *args], success=False)


def expect_allowed(*args):
    result = as_alice(*args)
    assert result.returncode == 0, 'alice must be allowed to run kubectl ' + ' '.join(args) + ' but got: ' + (result.stderr.strip().splitlines() or ['no output'])[-1]


def expect_forbidden(*args):
    result = as_alice(*args)
    assert result.returncode != 0 and FORBIDDEN in result.stderr.lower(), 'alice must get Forbidden for kubectl ' + ' '.join(args)


def dry_run(namespace, *args):
    return ['-n', namespace, *args, '--dry-run=server', '-o', 'name']


if wants('tenant-a-access'):
    binding = get('rolebinding', 'tenant-editor', TENANT_A)
    assert binding['roleRef']['kind'] == 'Role' and binding['roleRef']['name'] == 'tenant-editor', 'The RoleBinding tenant-editor must reference the Role tenant-editor'
    subjects = [(item.get('kind'), item.get('name')) for item in binding.get('subjects') or []]
    assert ('User', 'alice') in subjects, 'The RoleBinding tenant-editor must name the user alice'
    get('role', 'tenant-editor', TENANT_A)
    expect_allowed(*dry_run(TENANT_A, 'create', 'deployment', 'web', '--image=docker.io/library/busybox:1.37.0'))
    expect_allowed(*dry_run(TENANT_A, 'run', 'web', '--image=docker.io/library/busybox:1.37.0'))
    expect_allowed(*dry_run(TENANT_A, 'create', 'service', 'clusterip', 'web', '--tcp=80:8080'))
    expect_allowed(*dry_run(TENANT_A, 'create', 'configmap', 'web', '--from-literal=mode=test'))
    expect_allowed('-n', TENANT_A, 'get', 'deployments,pods,services,configmaps')

if wants('no-secrets'):
    expect_forbidden('-n', TENANT_A, 'get', 'secrets')
    expect_forbidden('-n', TENANT_A, 'get', 'secret', 'api-key')
    expect_forbidden(*dry_run(TENANT_A, 'create', 'secret', 'generic', 'stolen', '--from-literal=key=value'))

if wants('other-namespaces-denied'):
    expect_forbidden(*dry_run(TENANT_B, 'create', 'deployment', 'web', '--image=docker.io/library/busybox:1.37.0'))
    expect_forbidden('-n', TENANT_B, 'get', 'pods')
    expect_forbidden('-n', TENANT_B, 'get', 'secret', 'api-key')
    expect_forbidden('get', 'nodes')
    expect_forbidden('get', 'namespaces')
    bindings = json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    named = [item['metadata']['name'] for item in bindings
             if any(subject.get('kind') == 'User' and subject.get('name') == 'alice' for subject in item.get('subjects') or [])]
    assert not named, 'No ClusterRoleBinding may name alice: ' + ', '.join(named)
