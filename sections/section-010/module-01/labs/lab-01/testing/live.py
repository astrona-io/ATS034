# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json
import subprocess

STARFLEET, OUTPOST = 'starfleet-034-010-01-01', 'outpost-034-010-01-01'
IMAGE = 'docker.io/library/busybox:1.37.0'
PLAIN_SPEC = {'containers': [{'name': 'check', 'image': IMAGE, 'command': ['sleep', '3600']}]}
PRIVILEGED_SPEC = {'containers': [{'name': 'check', 'image': IMAGE, 'command': ['sleep', '3600'],
                                   'securityContext': {'privileged': True}}]}
RESTRICTED_SPEC = {
    'securityContext': {'runAsNonRoot': True, 'runAsUser': 1000, 'seccompProfile': {'type': 'RuntimeDefault'}},
    'containers': [{'name': 'check', 'image': IMAGE, 'command': ['sleep', '3600'],
                    'securityContext': {'allowPrivilegeEscalation': False, 'capabilities': {'drop': ['ALL']}}}],
}


def dry_run(namespace, spec):
    """Send a Pod as a server-side dry run: admission runs, nothing is stored."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'dry-run-check', 'namespace': namespace}, 'spec': spec}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod),
                          text=True, capture_output=True, timeout=20)


def assert_admitted(namespace, spec, label):
    result = dry_run(namespace, spec)
    assert result.returncode == 0, label + ' must be admitted in ' + namespace + ': ' + result.stderr.strip()


def assert_rejected(namespace, spec, label, profile):
    result = dry_run(namespace, spec)
    assert result.returncode != 0 and 'violates PodSecurity "' + profile + ':' in result.stderr, \
        label + ' must be rejected by Pod Security Admission under the ' + profile + ' profile in ' + namespace


def assert_ready(namespace, name):
    status = get('pod', name, namespace).get('status', {})
    ready = any(item['type'] == 'Ready' and item['status'] == 'True' for item in status.get('conditions', []))
    assert status.get('phase') == 'Running' and ready, 'The existing Pod ' + name + ' in ' + namespace + ' must keep running'


if wants('baseline-enforced'):
    assert_rejected(STARFLEET, PRIVILEGED_SPEC, 'A privileged Pod', 'baseline')
    assert_admitted(STARFLEET, PLAIN_SPEC, 'A plain Pod')
    assert_ready(STARFLEET, 'shuttle')
if wants('restricted-enforced'):
    assert_rejected(OUTPOST, PLAIN_SPEC, 'A plain Pod', 'restricted')
    assert_admitted(OUTPOST, RESTRICTED_SPEC, 'A Pod that meets Restricted')
    assert_ready(OUTPOST, 'drifter')
