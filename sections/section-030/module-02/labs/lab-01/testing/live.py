if wants('worker-label'):
    assert get('node', WORKER, namespace=None)['metadata'].get('labels', {}).get('sandbox') == 'true', 'Label the worker node sandbox=true'
if wants('sandboxed-pod'):
    behavior_check({'args':['kubectl','-n','tenant-b-034-030-02-01','get','pod','sandboxed-app','-o','jsonpath={.spec.nodeName}'],'equals':WORKER})
