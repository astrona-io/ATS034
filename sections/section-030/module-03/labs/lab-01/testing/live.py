if wants('worker-label') or wants('worker-taint'):
    worker = get('node', WORKER, namespace=None)
if wants('worker-label'):
    assert worker['metadata'].get('labels', {}).get('tenant') == 'tenant-c', 'Label the worker node tenant=tenant-c'
if wants('worker-taint'):
    assert contains(worker['spec'].get('taints', []), [{'key': 'tenant', 'value': 'tenant-c', 'effect': 'NoSchedule'}]), 'Taint the worker node tenant=tenant-c:NoSchedule'
if wants('tenant-deployment'):
    behavior_check({'args':['kubectl','-n','tenant-c-034-030-03-01','get','pods','-l','app=tenant-c-app','-o','jsonpath={.items[0].spec.nodeName}'],'equals':WORKER})
