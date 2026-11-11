if wants('configmap-removed'):
    result = command(['kubectl', '-n', NAMESPACE, 'get', 'configmap', 'legacy-settings'], success=False)
    assert result.returncode == 1 and 'not found' in result.stderr.lower(), 'Delete the ConfigMap legacy-settings in namespace ' + NAMESPACE
