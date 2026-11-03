import json
import subprocess

PLAIN_SPEC = {'containers': [{'name': 'check', 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sleep', '3600']}]}
PRIVILEGED_SPEC = {'containers': [{'name': 'check', 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sleep', '3600'],
                                   'securityContext': {'privileged': True}}]}


def dry_run(namespace, spec):
    """Send a Pod to the API server as a server-side dry run, so admission runs and nothing is stored."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'dry-run-check', 'namespace': namespace}, 'spec': spec}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod),
                          text=True, capture_output=True, timeout=20)


def assert_admitted(namespace, spec, label):
    result = dry_run(namespace, spec)
    assert result.returncode == 0, label + ' must be admitted in ' + namespace


def assert_rejected(namespace, spec, label):
    result = dry_run(namespace, spec)
    assert result.returncode != 0 and 'violates PodSecurity' in result.stderr, label + ' must be rejected by Pod Security Admission in ' + namespace

assert_admitted('starfleet', PLAIN_SPEC, 'A plain Pod')
assert_rejected('starfleet', PRIVILEGED_SPEC, 'A privileged Pod')
assert_rejected('outpost', PLAIN_SPEC, 'A plain Pod')
assert_rejected('outpost', PRIVILEGED_SPEC, 'A privileged Pod')
