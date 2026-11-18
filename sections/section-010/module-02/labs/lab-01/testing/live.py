# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json


def running_probe_pods():
    """The probe Pods that run now, without the ones an old rollout is removing."""
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe,release=probe', '-o', 'json'))['items']
    return {item['metadata']['name']: item for item in pods
            if item['status'].get('phase') == 'Running' and not item['metadata'].get('deletionTimestamp')}


def user_id(pod_name):
    result = command(['kubectl', '-n', NAMESPACE, 'exec', pod_name, '--', 'id', '-u'], success=False)
    assert result.returncode == 0, 'Could not run id in ' + pod_name
    return result.stdout.strip()


def requires_non_root(pod):
    """runAsNonRoot can be set on the Pod or on the container; the container value wins."""
    container = next(item for item in pod['spec']['containers'] if item['name'] == 'probe')
    own = (container.get('securityContext') or {}).get('runAsNonRoot')
    return own if own is not None else (pod['spec'].get('securityContext') or {}).get('runAsNonRoot')


if wants('probe-non-root'):
    pods = running_probe_pods()
    assert len(pods) == 2, 'Two probe Pods must be running, found ' + str(len(pods))
    for name, pod in pods.items():
        assert requires_non_root(pod) is True, name + ' must set runAsNonRoot: true'
        assert user_id(name) == '1000', name + ' must run as user ID 1000'

if wants('service-answers'):
    # The reply names the Pod that answered; that Pod must run as user 1000.
    reply = command(['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'http://probe/'], success=False)
    assert reply.returncode == 0, 'shuttle got no reply from http://probe/'
    fields = dict(part.split('=', 1) for part in reply.stdout.split() if '=' in part)
    assert fields.get('version') == 'v1', 'The probe reply is not the probe application'
    host = fields.get('host', '')
    assert host in running_probe_pods(), 'The reply came from ' + host + ', which is not a running probe Pod'
    assert user_id(host) == '1000', 'The Pod that answered, ' + host + ', must run as user ID 1000'
