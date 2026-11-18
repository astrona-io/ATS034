# Checks that read containerd and the running Pods on the lab VM. check.py
# runs this file with NODE, WORKER, node_exec(), kubectl(), get() and wants()
# already defined.
TENANT = 'tenant-b-034-030-02-01'


def runtime_handlers():
    """The runtime handlers that the running containerd has loaded."""
    info = json.loads(node_exec(NODE, 'crictl', 'info').stdout)
    return info.get('config', {}).get('containerd', {}).get('runtimes', {})


def pod_sandbox(namespace, name):
    """The containerd Pod sandbox of a running Pod, as crictl reports it."""
    found = json.loads(node_exec(NODE, 'crictl', 'pods', '--namespace', namespace, '--name', name, '--state', 'ready', '-o', 'json').stdout)
    items = [item for item in found.get('items', []) if item['metadata']['name'] == name]
    assert items, 'containerd has no ready Pod sandbox for ' + namespace + '/' + name
    return items[0]


if wants('containerd-handler'):
    handlers = runtime_handlers()
    assert handlers.get('runsc', {}).get('runtimeType') == 'io.containerd.runsc.v1', \
        'containerd must load the handler runsc with runtime_type io.containerd.runsc.v1'
    assert handlers.get('runc', {}).get('runtimeType') == 'io.containerd.runc.v2', \
        'containerd must keep the default handler runc'
    saved = node_exec(NODE, 'cat', '/etc/containerd/config.toml').stdout
    assert 'containerd.runtimes.runsc]' in saved, 'The runsc handler must be saved in /etc/containerd/config.toml'

if wants('sandboxed-pod'):
    pod = get('pod', 'scout', namespace=TENANT)
    assert pod['spec'].get('runtimeClassName') == 'gvisor', 'Pod scout must keep runtimeClassName: gvisor'
    status = pod.get('status', {})
    assert status.get('phase') == 'Running' and any(item['type'] == 'Ready' and item['status'] == 'True'
                                                    for item in status.get('conditions', [])), 'Pod scout must be running and ready'
    sandbox = pod_sandbox(TENANT, 'scout')
    assert sandbox.get('runtimeHandler') == 'runsc', 'containerd must run the Pod sandbox of scout with the runtime handler runsc'
    kernel_log = kubectl('-n', TENANT, 'exec', 'scout', '--', 'dmesg')
    assert 'Starting gVisor' in kernel_log, 'dmesg inside scout must show the gVisor kernel log'
    shuttle = pod_sandbox('starfleet-034-030-02-01', 'shuttle')
    assert shuttle.get('runtimeHandler', '') in ('', 'runc'), 'Pods without a RuntimeClass must keep the default handler'
