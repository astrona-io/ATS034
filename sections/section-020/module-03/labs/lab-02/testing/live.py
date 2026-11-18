# Checks that read the kube-apiserver process and the audit log file on the
# lab VM. check.py runs this file with NODE, node_exec(), command(),
# kubectl(), get() and wants() already defined.
import json
import secrets
import time

NS = 'starfleet-034-020-03-02'
LOG_PATH = '/var/log/kubernetes/audit/audit.log'
POLICY_PATH = '/etc/kubernetes/audit/policy.yaml'
AUDITOR = 'system:serviceaccount:' + NS + ':auditor'


def process_arguments(program):
    found = node_exec(NODE, 'pgrep', '-n', '-f', '^(/[^ ]*/)?' + program + '( |$)', success=False).stdout.strip()
    assert found, program + ' is not running'
    raw = node_exec(NODE, 'cat', '/proc/' + found + '/cmdline', success=False).stdout
    return [item for item in raw.split('\0') if item]


def flag_value(arguments, flag):
    values = [item.split('=', 1)[1] for item in arguments if item.startswith(flag + '=')]
    return values[-1] if values else None


def secret_events(name):
    """Parsed audit events that name the Secret, read from the node."""
    result = node_exec(NODE, 'grep', '-h', '"name":"' + name + '"', LOG_PATH, success=False)
    events = []
    for line in result.stdout.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        reference = event.get('objectRef') or {}
        if reference.get('resource') == 'secrets' and reference.get('namespace') == NS and reference.get('name') == name:
            events.append(event)
    return events


def completed_gets(events):
    return [e for e in events if e.get('verb') == 'get' and e.get('stage') == 'ResponseComplete']


def assert_metadata_only(event, what):
    assert event.get('level') == 'Metadata', what + ' was logged at level ' + str(event.get('level')) + '; Secrets must be logged at Metadata'
    assert 'requestObject' not in event and 'responseObject' not in event, what + ' contains a request or response body'


if wants('audit-enabled'):
    arguments = process_arguments('kube-apiserver')
    assert flag_value(arguments, '--audit-policy-file') == POLICY_PATH, 'kube-apiserver must run with --audit-policy-file=' + POLICY_PATH
    assert flag_value(arguments, '--audit-log-path') == LOG_PATH, 'kube-apiserver must run with --audit-log-path=' + LOG_PATH
    # Proof by a real request: a fresh Secret get must reach the log at Metadata.
    name = 'grader-audit-' + secrets.token_hex(4)
    kubectl('-n', NS, 'create', 'secret', 'generic', name, '--from-literal=value=grader')
    try:
        kubectl('-n', NS, 'get', 'secret', name, '-o', 'name')
        found = []
        for _ in range(10):
            found = completed_gets(secret_events(name))
            if found:
                break
            time.sleep(1)
        assert found, 'A get of a Secret did not appear in ' + LOG_PATH
        assert_metadata_only(found[-1], 'A get of a Secret')
    finally:
        kubectl('-n', NS, 'delete', 'secret', name, '--ignore-not-found')

if wants('auditor-read-logged'):
    events = completed_gets(secret_events('probe-credentials'))
    by_auditor = [e for e in events if AUDITOR in ((e.get('user') or {}).get('username'), (e.get('impersonatedUser') or {}).get('username'))]
    allowed = [e for e in by_auditor if (e.get('responseStatus') or {}).get('code') == 200]
    assert allowed, 'No successful get of Secret probe-credentials by ' + AUDITOR + ' in ' + LOG_PATH
    assert_metadata_only(allowed[-1], 'The get of probe-credentials')
