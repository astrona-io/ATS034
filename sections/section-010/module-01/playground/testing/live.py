# The API server adds the service account token volume, so match the lab's own volume and mount by name.
pod = get('pod', 'restricted-reader', namespace='restricted')
for expected in [{'name': 'scratch', 'emptyDir': {}}]:
    assert any(contains(volume, expected) for volume in pod['spec'].get('volumes', [])), 'Missing volume ' + expected['name']
for expected in [{'name': 'scratch', 'mountPath': '/scratch'}]:
    assert any(contains(mount, expected) for mount in pod['spec']['containers'][0].get('volumeMounts', [])), 'Missing volume mount ' + expected['mountPath']
