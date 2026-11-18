# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get(), node_exec(), NODE and WORKER are available here.
import json

TENANT = 'tenant-d-034-030-03-02'
PROTECTED = 'node-restriction.kubernetes.io/tenant'
KUBELET_KUBECONFIG = '/etc/kubernetes/kubelet.conf'


def labels(name):
    return get('node', name, namespace=None)['metadata'].get('labels', {})


def as_kubelet(*args):
    """Send a request with the kubelet credentials of the worker, from the worker node."""
    return node_exec(WORKER, 'kubectl', '--kubeconfig', KUBELET_KUBECONFIG, *args, success=False)


if wants('protected-label'):
    worker = labels(WORKER)
    assert worker.get(PROTECTED) == 'tenant-d', 'Label the worker node ' + PROTECTED + '=tenant-d'
    assert 'tenant' not in worker, 'Remove the plain label tenant from the worker node'
    assert PROTECTED not in labels(NODE), 'Do not give the control-plane node the label ' + PROTECTED
    who = as_kubelet('auth', 'whoami', '-o', 'jsonpath={.status.userInfo.username}')
    assert who.returncode == 0 and who.stdout.strip() == 'system:node:' + WORKER, 'The kubelet credentials of the worker must authenticate as system:node:' + WORKER
    # NodeRestriction is an admission plugin, so a server-side dry run reaches it.
    attempt = as_kubelet('label', 'node', WORKER, PROTECTED + '=tenant-x', '--overwrite', '--dry-run=server')
    output = attempt.stdout + attempt.stderr
    assert attempt.returncode != 0 and 'forbidden' in output.lower() and PROTECTED in output, \
        'The kubelet credentials must get Forbidden when they change ' + PROTECTED
    assert labels(WORKER).get(PROTECTED) == 'tenant-d', 'The protected label must keep the value tenant-d'

if wants('tenant-workload'):
    deployment = get('deployment', 'tenant-d-app', TENANT)
    selector = deployment['spec']['template']['spec'].get('nodeSelector', {})
    assert selector == {PROTECTED: 'tenant-d'}, 'The Pod template of tenant-d-app must select only ' + PROTECTED + ': tenant-d'
    status = deployment.get('status', {})
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'] and status.get('updatedReplicas', 0) == 1 \
        and status.get('readyReplicas', 0) == 1 and status.get('replicas', 0) == 1, 'Deployment tenant-d-app must finish its rollout with one ready replica'
    pods = json.loads(kubectl('-n', TENANT, 'get', 'pods', '-l', 'app=tenant-d-app', '-o', 'json'))['items']
    running = [pod for pod in pods if pod.get('status', {}).get('phase') == 'Running' and not pod['metadata'].get('deletionTimestamp')]
    assert running and all(pod['spec'].get('nodeName') == WORKER for pod in running), 'The Pod of tenant-d-app must run on the worker node ' + WORKER
    assert all(pod['spec'].get('nodeSelector', {}) == {PROTECTED: 'tenant-d'} for pod in running), 'The running Pod must come from the updated template'
