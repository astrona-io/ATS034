# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get(), command() and WORKER are available here.
import json

TENANT, OTHER = 'tenant-e-034-030-03-03', 'starfleet-034-030-03-03'
IMAGE = 'docker.io/library/busybox:1.37.0'
SELECTOR = {'node-restriction.kubernetes.io/tenant': 'tenant-e'}


def dry_run_pod(namespace, selector=None):
    """Send a Pod create request through admission without storing it."""
    args = ['kubectl', '-n', namespace, 'run', 'admission-check', '--image=' + IMAGE, '--dry-run=server', '-o', 'name']
    if selector:
        args.append('--overrides=' + json.dumps({'spec': {'nodeSelector': selector}}))
    return command(args, success=False)


if wants('require-node-selector'):
    policy = get('validatingadmissionpolicy', 'require-tenant-node', namespace=None)
    assert any('CREATE' in rule.get('operations', []) and 'pods' in rule.get('resources', [])
               for rule in policy['spec'].get('matchConstraints', {}).get('resourceRules', [])), 'The policy require-tenant-node must match CREATE requests for pods'
    binding = get('validatingadmissionpolicybinding', 'require-tenant-node-tenant-e', namespace=None)
    assert binding['spec'].get('policyName') == 'require-tenant-node', 'The binding require-tenant-node-tenant-e must name the policy require-tenant-node'
    assert 'Deny' in binding['spec'].get('validationActions', []), 'The binding require-tenant-node-tenant-e must use the validation action Deny'
    for case, selector in (('no node selector', None), ('another tenant', {'node-restriction.kubernetes.io/tenant': 'tenant-x'})):
        denied = dry_run_pod(TENANT, selector)
        output = denied.stdout + denied.stderr
        assert denied.returncode != 0 and 'require-tenant-node' in output and 'denied request' in output, \
            'A new Pod in ' + TENANT + ' with ' + case + ' must be denied by require-tenant-node'
        assert 'Pods must select node-restriction.kubernetes.io/tenant=tenant-e' in output, 'The denial must show the message: Pods must select node-restriction.kubernetes.io/tenant=tenant-e'
    allowed = dry_run_pod(TENANT, SELECTOR)
    assert allowed.returncode == 0, 'A new Pod with the tenant-e node selector must be admitted: ' + allowed.stderr.strip()
    other = dry_run_pod(OTHER)
    assert other.returncode == 0, 'A Pod without a node selector in ' + OTHER + ' must still be admitted: ' + other.stderr.strip()

if wants('tenant-workload'):
    deployment = get('deployment', 'tenant-e-app', TENANT)
    template = deployment['spec']['template']['spec']
    assert template.get('nodeSelector', {}).get('node-restriction.kubernetes.io/tenant') == 'tenant-e', \
        'The Pod template of tenant-e-app must set the node selector node-restriction.kubernetes.io/tenant: tenant-e'
    status = deployment.get('status', {})
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'] and status.get('updatedReplicas', 0) == 1 \
        and status.get('readyReplicas', 0) == 1 and status.get('replicas', 0) == 1, 'Deployment tenant-e-app must finish its rollout with one ready replica'
    pods = json.loads(kubectl('-n', TENANT, 'get', 'pods', '-l', 'app=tenant-e-app', '-o', 'json'))['items']
    running = [pod for pod in pods if pod.get('status', {}).get('phase') == 'Running']
    assert running and all(pod['spec'].get('nodeName') == WORKER for pod in running), 'The Pod of tenant-e-app must run on the worker node ' + WORKER
    assert all(pod['spec'].get('nodeSelector', {}).get('node-restriction.kubernetes.io/tenant') == 'tenant-e' for pod in running), \
        'The running Pod must come from the updated template'
