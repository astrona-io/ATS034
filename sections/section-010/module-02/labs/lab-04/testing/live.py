# Live checks for this lab. check.py runs this file in its own globals, so
# wants(), kubectl(), get() and command() are available here.
import json


def running_collector_pods():
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=collector', '-o', 'json'))['items']
    return [item for item in pods if item['status'].get('phase') == 'Running' and not item['metadata'].get('deletionTimestamp')]


if wants('node-isolated'):
    pods = running_collector_pods()
    assert len(pods) == 1, 'One collector Pod must be running, found ' + str(len(pods))
    pod = pods[0]
    name = pod['metadata']['name']
    # A Pod in the node network namespace gets the IP address of the node.
    assert not pod['spec'].get('hostNetwork'), name + ' must not use hostNetwork'
    assert pod['status'].get('podIP') and pod['status']['podIP'] != pod['status'].get('hostIP'), name + ' must have its own IP address, not the node address'
    logs = next((volume for volume in pod['spec'].get('volumes', []) if volume['name'] == 'logs'), None)
    assert logs is not None and 'emptyDir' in logs, 'The volume logs must be an emptyDir volume'
    # The node's /var/log holds the pods and containers directories; an emptyDir starts empty.
    listing = command(['kubectl', '-n', NAMESPACE, 'exec', name, '--', 'ls', '-A', '/logs'], success=False)
    assert listing.returncode == 0, 'Could not list /logs in ' + name
    assert 'pods' not in listing.stdout.split() and 'containers' not in listing.stdout.split(), '/logs still shows the log directory of the node'
    written = command(['kubectl', '-n', NAMESPACE, 'exec', name, '--', 'touch', '/logs/grader-check'], success=False)
    assert written.returncode == 0, 'The collector process must be able to write to /logs'
