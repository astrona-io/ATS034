# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json
import subprocess

PLAIN_POD = {'containers': [{'name': 'check', 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sleep', '3600']}]}
RESTRICTED = 'restricted:v1.35'


def dry_run(namespace):
    """Send a Pod without security settings through admission; nothing is stored."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'dry-run-check', 'namespace': namespace}, 'spec': PLAIN_POD}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod),
                          text=True, capture_output=True, timeout=20)


def label(namespace, mode):
    return get('namespace', namespace, namespace=None)['metadata'].get('labels', {}).get('pod-security.kubernetes.io/' + mode)


if wants('compliant-enforced'):
    result = dry_run('bridge-034-010-03-01')
    assert result.returncode != 0 and 'violates PodSecurity "' + RESTRICTED + '"' in result.stderr, \
        'bridge-034-010-03-01 must enforce Restricted pinned to v1.35'
    ready = kubectl('-n', 'bridge-034-010-03-01', 'get', 'deployment', 'bridge', '-o', 'jsonpath={.status.readyReplicas}')
    assert ready == '1', 'The bridge Deployment must stay Ready'

if wants('noncompliant-warned'):
    for namespace in ('starfleet-034-010-03-01', 'outpost-034-010-03-01'):
        # Enforcing Restricted here would block the next Pod of the running workload.
        assert label(namespace, 'enforce') in (None, 'privileged', 'baseline'), namespace + ' must not enforce Restricted yet'
        result = dry_run(namespace)
        assert result.returncode == 0, 'A Pod without security settings must still be admitted in ' + namespace
        assert 'would violate PodSecurity "' + RESTRICTED + '"' in result.stderr, \
            namespace + ' must warn on Restricted pinned to v1.35'
