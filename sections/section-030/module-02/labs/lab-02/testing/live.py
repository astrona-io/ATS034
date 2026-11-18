# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get(), command(), NODE and WORKER are available here.
import json

TENANT_B = 'tenant-b-034-030-02-02'
OVERHEAD = {'cpu': '50m', 'memory': '64Mi'}
SELECTOR = {'sandbox': 'true'}


def ready(pod):
    return pod.get('status', {}).get('phase') == 'Running' and any(
        item['type'] == 'Ready' and item['status'] == 'True' for item in pod.get('status', {}).get('conditions', []))


if wants('runtimeclass'):
    runtime_class = get('runtimeclass', 'sandboxed', namespace=None)
    assert runtime_class.get('handler') == 'runc', 'RuntimeClass sandboxed must use the handler runc'
    assert runtime_class.get('overhead', {}).get('podFixed') == OVERHEAD, 'RuntimeClass sandboxed must set overhead.podFixed to cpu 50m and memory 64Mi'
    assert runtime_class.get('scheduling', {}).get('nodeSelector') == SELECTOR, 'RuntimeClass sandboxed must set scheduling.nodeSelector sandbox: "true"'
    # The RuntimeClass admission plugin must add both fields to a new Pod.
    result = command(['kubectl', '-n', TENANT_B, 'run', 'overhead-check', '--image=docker.io/library/busybox:1.37.0',
                      '--overrides={"spec":{"runtimeClassName":"sandboxed"}}', '--dry-run=server', '-o', 'json'], success=False)
    assert result.returncode == 0, 'A dry-run Pod with runtimeClassName sandboxed was rejected: ' + result.stderr.strip()
    spec = json.loads(result.stdout)['spec']
    assert spec.get('overhead') == OVERHEAD, 'The API server did not add the class overhead to a new Pod'
    assert spec.get('nodeSelector', {}).get('sandbox') == 'true', 'The API server did not add the class node selector to a new Pod'

if wants('worker-label'):
    assert get('node', WORKER, namespace=None)['metadata'].get('labels', {}).get('sandbox') == 'true', 'Label the worker node sandbox=true'
    assert 'sandbox' not in get('node', NODE, namespace=None)['metadata'].get('labels', {}), 'Do not label the control-plane node with sandbox'

if wants('sandboxed-pod'):
    pod = get('pod', 'sandboxed-app', TENANT_B)
    spec = pod['spec']
    assert spec.get('runtimeClassName') == 'sandboxed', 'Pod sandboxed-app must set runtimeClassName: sandboxed'
    assert spec['containers'][0]['image'] == 'docker.io/library/busybox:1.37.0', 'Pod sandboxed-app must run docker.io/library/busybox:1.37.0'
    assert spec.get('overhead') == OVERHEAD, 'Pod sandboxed-app must carry the overhead that the class adds'
    assert spec.get('nodeSelector', {}).get('sandbox') == 'true', 'Pod sandboxed-app must carry the node selector that the class adds'
    assert spec.get('nodeName') == WORKER, 'Pod sandboxed-app must run on the worker node ' + WORKER
    assert ready(pod), 'Pod sandboxed-app must be Running and Ready'
