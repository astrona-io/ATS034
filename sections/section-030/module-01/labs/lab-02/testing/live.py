# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json

NS = 'tenant-a-034-030-01-02'
UNITS = {'Ki': 2 ** 10, 'Mi': 2 ** 20, 'Gi': 2 ** 30, 'K': 10 ** 3, 'M': 10 ** 6, 'G': 10 ** 9}


def memory(value):
    """Turn a Kubernetes memory quantity (128Mi, 134217728) into bytes."""
    value = str(value)
    for suffix in sorted(UNITS, key=len, reverse=True):
        if value.endswith(suffix):
            return int(float(value[:-len(suffix)]) * UNITS[suffix])
    return int(value)


def burst_pods():
    pods = json.loads(kubectl('-n', NS, 'get', 'pods', '-l', 'app=burst', '-o', 'json'))['items']
    return [pod for pod in pods if pod['metadata'].get('deletionTimestamp') is None]


def big_pod_rejection():
    """A server-side dry run of a Pod that asks for more memory than the whole quota."""
    return command(['kubectl', '-n', NS, 'run', 'oversized', '--image=docker.io/library/busybox:1.37.0',
                    '--overrides', json.dumps({'spec': {'containers': [{'name': 'oversized', 'image': 'docker.io/library/busybox:1.37.0',
                                                                        'resources': {'requests': {'memory': '512Mi'}, 'limits': {'memory': '512Mi'}}}]}}),
                    '--dry-run=server', '-o', 'name'], success=False)


if wants('compute-budget'):
    hard = get('resourcequota', 'compute-budget', NS)['spec'].get('hard', {})
    assert hard.get('pods') == '2', 'The quota must allow 2 Pods'
    assert 'requests.memory' in hard and memory(hard['requests.memory']) == memory('128Mi'), 'The quota must allow 128Mi of memory requests'
    assert 'limits.memory' in hard and memory(hard['limits.memory']) == memory('256Mi'), 'The quota must allow 256Mi of memory limits'
    result = big_pod_rejection()
    assert result.returncode != 0 and 'exceeded quota: compute-budget' in result.stderr, 'The API server must reject a Pod that goes over compute-budget'

if wants('container-defaults'):
    limits = get('limitrange', 'container-defaults', NS)['spec'].get('limits') or []
    containers = [item for item in limits if item.get('type') == 'Container']
    assert containers, 'The LimitRange needs a limit of type Container'
    assert any(memory((item.get('defaultRequest') or {}).get('memory', 0)) == memory('32Mi') and memory((item.get('default') or {}).get('memory', 0)) == memory('64Mi')
               for item in containers), 'The defaults must be a 32Mi memory request and a 64Mi memory limit'
    pods = burst_pods()
    assert pods, 'No burst Pod exists, so the defaults were never added to a Pod'
    for pod in pods:
        resources = pod['spec']['containers'][0].get('resources', {})
        assert memory(resources.get('requests', {}).get('memory', 0)) == memory('32Mi'), 'Pod ' + pod['metadata']['name'] + ' did not receive the 32Mi request'
        assert memory(resources.get('limits', {}).get('memory', 0)) == memory('64Mi'), 'Pod ' + pod['metadata']['name'] + ' did not receive the 64Mi limit'

if wants('third-replica-blocked'):
    deployment = get('deployment', 'burst', NS)
    assert deployment['spec'].get('replicas') == 3, 'The burst Deployment must ask for 3 replicas'
    for container in deployment['spec']['template']['spec']['containers']:
        assert not container.get('resources'), 'The burst container must declare no resources; the LimitRange adds them'
    running = [pod for pod in burst_pods() if pod['status'].get('phase') == 'Running']
    assert len(running) == 2, f'Exactly 2 burst Pods must run, found {len(running)}'
    conditions = deployment.get('status', {}).get('conditions', [])
    failure = [item for item in conditions if item['type'] == 'ReplicaFailure' and item['status'] == 'True']
    assert failure and 'exceeded quota: compute-budget' in failure[0].get('message', ''), 'The Deployment must report that the quota rejected the third Pod'
