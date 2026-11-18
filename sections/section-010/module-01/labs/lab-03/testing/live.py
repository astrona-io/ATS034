# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json
import subprocess

IMAGE = 'docker.io/library/busybox:1.37.0'
PLAIN_SPEC = {'containers': [{'name': 'check', 'image': IMAGE, 'command': ['sleep', '3600']}]}
PRIVILEGED_SPEC = {'containers': [{'name': 'check', 'image': IMAGE, 'command': ['sleep', '3600'],
                                   'securityContext': {'privileged': True}}]}


def dry_run(spec):
    """Send a Pod as a server-side dry run: admission runs, nothing is stored."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'dry-run-check', 'namespace': NAMESPACE}, 'spec': spec}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod),
                          text=True, capture_output=True, timeout=20)


def assert_shuttle_running():
    status = get('pod', 'shuttle').get('status', {})
    ready = any(item['type'] == 'Ready' and item['status'] == 'True' for item in status.get('conditions', []))
    assert status.get('phase') == 'Running' and ready, 'The existing shuttle Pod must keep running'


if wants('baseline-enforced'):
    rejected = dry_run(PRIVILEGED_SPEC)
    assert rejected.returncode != 0 and 'violates PodSecurity "baseline:v1.35"' in rejected.stderr, \
        'A privileged Pod must be rejected under baseline:v1.35'
    admitted = dry_run(PLAIN_SPEC)
    assert admitted.returncode == 0, 'A plain Pod must be admitted: ' + admitted.stderr.strip()
    assert_shuttle_running()
if wants('restricted-warning'):
    labels = get('namespace', NAMESPACE, None)['metadata'].get('labels', {})
    assert labels.get('pod-security.kubernetes.io/audit') == 'restricted', 'Set the audit mode to restricted'
    assert labels.get('pod-security.kubernetes.io/audit-version') == 'v1.35', 'Pin the audit mode to v1.35'
    admitted = dry_run(PLAIN_SPEC)
    assert admitted.returncode == 0, 'A plain Pod must be admitted: ' + admitted.stderr.strip()
    assert 'would violate PodSecurity "restricted:v1.35"' in admitted.stderr, \
        'Creating a plain Pod must print the warning that it would violate restricted:v1.35'
    assert_shuttle_running()
