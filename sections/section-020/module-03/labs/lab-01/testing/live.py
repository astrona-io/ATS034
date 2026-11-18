# Live checks for moving a leaked credential into a Secret. check.py runs this
# file with kubectl(), get(), command(), contains() and wants() defined.
NS = 'starfleet-034-020-03-01'
VALUE = 'disposable-scout'


def literal_values(template):
    """Every literal env value in the pod template, init containers included."""
    spec = template['spec']
    containers = (spec.get('containers') or []) + (spec.get('initContainers') or [])
    return [item.get('value') or '' for c in containers for item in c.get('env') or []]


if wants('deployment-uses-secret'):
    deployment = get('deployment', 'scout', NS)
    template = deployment['spec']['template']
    assert not any(VALUE in value for value in literal_values(template)), \
        'The pod template of Deployment scout still holds the credential as a literal value'
    reference = {'name': 'API_TOKEN', 'valueFrom': {'secretKeyRef': {'name': 'scout-credentials', 'key': 'token'}}}
    container = template['spec']['containers'][0]
    assert any(contains(item, reference) for item in container.get('env') or []), \
        'API_TOKEN must come from the key token of Secret scout-credentials'
    status = deployment.get('status') or {}
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'] \
        and status.get('updatedReplicas') == deployment['spec']['replicas'] == status.get('readyReplicas') \
        and not status.get('unavailableReplicas'), 'The rollout of Deployment scout is not complete'
    result = command(['kubectl', '-n', NS, 'exec', 'deployment/scout', '--', 'sh', '-c',
                      'test "$API_TOKEN" = ' + VALUE + ' && echo match || echo different'], success=False)
    assert result.stdout.strip() == 'match', 'API_TOKEN in the running scout container does not hold the credential'

if wants('configmap-removed'):
    result = command(['kubectl', '-n', NS, 'get', 'configmap', 'legacy-settings'], success=False)
    assert result.returncode == 1 and 'not found' in result.stderr.lower(), 'Delete the ConfigMap legacy-settings'
