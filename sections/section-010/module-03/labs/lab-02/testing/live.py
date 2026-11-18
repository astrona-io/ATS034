# Live checks for this lab. check.py runs this file inside the lab VM with
# NODE, node_exec(), kubectl(), get(), command() and wants() already defined.
import json
import subprocess

STARFLEET = 'starfleet-034-010-03-02'
AGENTS = 'node-agents-034-010-03-02'
CONTAINER = {'name': 'check', 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sleep', '3600']}
PLAIN_POD = {'containers': [CONTAINER]}
PRIVILEGED_POD = {'containers': [dict(CONTAINER, securityContext={'privileged': True})]}


def dry_run(namespace, spec):
    """Send a Pod through admission as a server-side dry run; nothing is stored."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'dry-run-check', 'namespace': namespace}, 'spec': spec}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod),
                          text=True, capture_output=True, timeout=20)


def assert_no_labels(namespace):
    # The task is about the cluster defaults, so namespace labels must not do the work.
    labels = get('namespace', namespace, namespace=None)['metadata'].get('labels', {})
    assert not [key for key in labels if key.startswith('pod-security.kubernetes.io/')], \
        namespace + ' must keep no pod-security.kubernetes.io labels'


if wants('default-baseline'):
    assert_no_labels(STARFLEET)
    privileged = dry_run(STARFLEET, PRIVILEGED_POD)
    assert privileged.returncode != 0 and 'violates PodSecurity "baseline:v1.35"' in privileged.stderr, \
        'A privileged Pod in ' + STARFLEET + ' must be rejected by the baseline:v1.35 default'
    plain = dry_run(STARFLEET, PLAIN_POD)
    assert plain.returncode == 0, 'A Pod without security settings must be admitted in ' + STARFLEET
    assert 'would violate PodSecurity "restricted:v1.35"' in plain.stderr, \
        'The default must warn on restricted:v1.35 in ' + STARFLEET

if wants('namespace-exempt'):
    assert_no_labels(AGENTS)
    elsewhere = dry_run(STARFLEET, PRIVILEGED_POD)
    assert elsewhere.returncode != 0, 'The defaults must reject a privileged Pod outside the exempt namespace'
    exempt = dry_run(AGENTS, PRIVILEGED_POD)
    assert exempt.returncode == 0, 'A privileged Pod must be admitted in ' + AGENTS
    assert 'PodSecurity' not in exempt.stderr, 'An exempt namespace gets no Pod Security warning, but ' + AGENTS + ' did'
