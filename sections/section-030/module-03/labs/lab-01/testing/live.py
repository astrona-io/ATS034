# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get(), contains(), NODE and WORKER are available here.
import json

TENANT, OUTPOST = 'tenant-c-034-030-03-01', 'outpost-034-030-03-01'
TAINT = {'key': 'tenant', 'value': 'tenant-c', 'effect': 'NoSchedule'}


def node(name):
    return get('node', name, namespace=None)


def has_taint(item):
    return any(contains(taint, TAINT) for taint in item['spec'].get('taints', []))


def condition(pod, kind):
    return next((item for item in pod.get('status', {}).get('conditions', []) if item['type'] == kind), {})


if wants('worker-label'):
    assert node(WORKER)['metadata'].get('labels', {}).get('tenant') == 'tenant-c', 'Label the worker node tenant=tenant-c'
    assert 'tenant' not in node(NODE)['metadata'].get('labels', {}), 'Do not label the control-plane node with tenant'

if wants('worker-taint'):
    assert has_taint(node(WORKER)), 'Taint the worker node tenant=tenant-c:NoSchedule'
    assert not any(taint.get('key') == 'tenant' for taint in node(NODE)['spec'].get('taints', [])), 'Do not taint the control-plane node with tenant'

if wants('tenant-deployment'):
    deployment = get('deployment', 'tenant-c-app', TENANT)
    template = deployment['spec']['template']['spec']
    assert template.get('nodeSelector', {}).get('tenant') == 'tenant-c', 'The Pod template of tenant-c-app must set the node selector tenant: tenant-c'
    assert any(item.get('key') == 'tenant' and item.get('operator') == 'Equal' and item.get('value') == 'tenant-c'
               and item.get('effect') == 'NoSchedule' for item in template.get('tolerations', [])), 'The Pod template of tenant-c-app must tolerate tenant=tenant-c:NoSchedule with the Equal operator'
    status = deployment.get('status', {})
    assert status.get('readyReplicas', 0) == deployment['spec'].get('replicas', 1) == 1, 'Deployment tenant-c-app must have one ready replica'
    pods = json.loads(kubectl('-n', TENANT, 'get', 'pods', '-l', 'app=tenant-c-app', '-o', 'json'))['items']
    running = [pod for pod in pods if pod.get('status', {}).get('phase') == 'Running']
    assert running, 'No Pod of tenant-c-app is Running'
    assert all(pod['spec'].get('nodeName') == WORKER for pod in running), 'Every Pod of tenant-c-app must run on the worker node ' + WORKER
    assert has_taint(node(WORKER)), 'The worker node must still have the taint tenant=tenant-c:NoSchedule'

if wants('stray-pod-pending'):
    pod = get('pod', 'drifter', OUTPOST)
    assert pod['spec'].get('nodeSelector', {}).get('tenant') == 'tenant-c', 'Pod drifter must set the node selector tenant: tenant-c'
    assert not any(item.get('key') == 'tenant' for item in pod['spec'].get('tolerations', [])), 'Pod drifter must not tolerate the tenant taint'
    assert pod.get('status', {}).get('phase') == 'Pending' and not pod['spec'].get('nodeName'), 'Pod drifter must stay Pending and unscheduled'
    scheduled = condition(pod, 'PodScheduled')
    assert scheduled.get('status') == 'False' and 'untolerated taint' in scheduled.get('message', ''), \
        'The scheduler must report the untolerated taint for Pod drifter'
