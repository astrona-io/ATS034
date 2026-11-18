# Live RBAC checks for ServiceAccount auditor. check.py runs this file with
# kubectl(), get(), command(), contains() and wants() defined. Every check asks
# the API server as the ServiceAccount, so any correct Role passes.
NS = 'starfleet-034-020-02-03'
AUDITOR = 'system:serviceaccount:' + NS + ':auditor'


def can_i(verb, resource):
    result = command(['kubectl', 'auth', 'can-i', verb, resource, '-n', NS, '--as', AUDITOR], success=False)
    return result.stdout.strip()


def get_as_auditor(name):
    return command(['kubectl', '-n', NS, 'get', 'secret', name, '--as', AUDITOR, '-o', 'name'], success=False)


def assert_reads_probe():
    assert can_i('get', 'secret/probe-credentials') == 'yes', 'auditor cannot get Secret probe-credentials'
    result = get_as_auditor('probe-credentials')
    assert result.returncode == 0, 'kubectl get secret probe-credentials --as auditor failed'


if wants('role-scoped'):
    assert_reads_probe()

if wants('others-denied'):
    # Guard: a ServiceAccount with no access at all must not pass this outcome.
    assert_reads_probe()
    for verb, resource in [('get', 'secret/other-credentials'), ('list', 'secrets'), ('watch', 'secrets'),
                           ('update', 'secret/probe-credentials'), ('delete', 'secret/probe-credentials'),
                           ('create', 'secrets')]:
        assert can_i(verb, resource) == 'no', 'auditor can ' + verb + ' ' + resource + '; allow only get on probe-credentials'
    result = get_as_auditor('other-credentials')
    assert result.returncode != 0 and 'forbidden' in result.stderr.lower(), 'A real get of other-credentials as auditor must be forbidden'
