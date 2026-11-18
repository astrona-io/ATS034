# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json
import subprocess

AGENTS = 'node-agents-034-010-03-03'
STARFLEET = 'starfleet-034-010-03-03'
DEPLOYER = 'system:serviceaccount:' + STARFLEET + ':deployer'
PRIVILEGED_POD = {'containers': [{'name': 'check', 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sleep', '3600'],
                                  'securityContext': {'privileged': True}}]}


def dry_run(namespace, spec):
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'dry-run-check', 'namespace': namespace}, 'spec': spec}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod),
                          text=True, capture_output=True, timeout=20)


def can_i(*args):
    return command(['kubectl', 'auth', 'can-i', *args, '--as=' + DEPLOYER], success=False).stdout.strip()


if wants('agent-admitted'):
    privileged = dry_run(AGENTS, PRIVILEGED_POD)
    assert privileged.returncode == 0, AGENTS + ' must enforce Privileged, so a privileged Pod is admitted'
    assert 'would violate PodSecurity "baseline:v1.35"' in privileged.stderr, \
        AGENTS + ' must warn on Baseline pinned to v1.35'
    labels = get('namespace', AGENTS, namespace=None)['metadata'].get('labels', {})
    assert labels.get('pod-security.kubernetes.io/enforce-version') == 'v1.35', 'The enforce version of ' + AGENTS + ' must be pinned to v1.35'
    assert labels.get('pod-security.kubernetes.io/audit') == 'baseline' and labels.get('pod-security.kubernetes.io/audit-version') == 'v1.35', \
        AGENTS + ' must audit on Baseline pinned to v1.35'
    pods = json.loads(kubectl('-n', AGENTS, 'get', 'pods', '-l', 'app=log-agent', '-o', 'json'))['items']
    running = [pod for pod in pods if pod['status'].get('phase') == 'Running' and not pod['metadata'].get('deletionTimestamp')]
    assert running, 'A log-agent Pod must be running'
    listing = command(['kubectl', '-n', AGENTS, 'exec', running[0]['metadata']['name'], '--', 'ls', '/host-logs'], success=False)
    assert listing.returncode == 0 and 'pods' in listing.stdout.split(), 'log-agent must read the node log directory at /host-logs'

if wants('labels-protected'):
    for verb in ('update', 'patch'):
        assert can_i(verb, 'namespaces') == 'no', 'deployer must not be allowed to ' + verb + ' namespaces'
    # A real request: lowering the enforce label as deployer must be forbidden.
    lowered = command(['kubectl', 'label', '--overwrite', '--dry-run=server', 'namespace', STARFLEET,
                       'pod-security.kubernetes.io/enforce=privileged', '--as=' + DEPLOYER], success=False)
    assert lowered.returncode != 0 and 'forbidden' in lowered.stderr.lower(), 'deployer must not be able to change namespace labels'
    assert can_i('create', 'deployments', '-n', STARFLEET) == 'yes', 'deployer must still create Deployments in ' + STARFLEET
