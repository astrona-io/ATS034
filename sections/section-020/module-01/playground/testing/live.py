# The API server adds the service account token volume, so match the lab's own volume and mount by name.
pod = get('pod', 'rotated-reader', namespace='starfleet')
for expected in [{'name': 'secret', 'secret': {'secretName': 'practice-token'}}]:
    assert any(contains(volume, expected) for volume in pod['spec'].get('volumes', [])), 'Missing volume ' + expected['name']
for expected in [{'name': 'secret', 'mountPath': '/credentials', 'readOnly': True}]:
    assert any(contains(mount, expected) for mount in pod['spec']['containers'][0].get('volumeMounts', [])), 'Missing volume mount ' + expected['mountPath']
