# Checks that read the running Pod and containerd on the lab VM. check.py runs
# this file with NODE, WORKER, node_exec(), kubectl(), get() and wants()
# already defined.
TENANT = 'tenant-a-034-030-01-04'


def pod_sandbox(namespace, name):
    """The containerd Pod sandbox of a running Pod, as crictl reports it."""
    found = json.loads(node_exec(NODE, 'crictl', 'pods', '--namespace', namespace, '--name', name, '--state', 'ready', '-o', 'json').stdout)
    items = [item for item in found.get('items', []) if item['metadata']['name'] == name]
    assert items, 'containerd has no ready Pod sandbox for ' + namespace + '/' + name
    return items[0]


if wants('sandboxed-pod'):
    pod = get('pod', 'sandboxed', namespace=TENANT)
    assert pod, 'Pod sandboxed must exist in ' + TENANT
    assert pod['spec'].get('runtimeClassName') == 'gvisor', 'Pod sandboxed must set runtimeClassName: gvisor'
    status = pod.get('status', {})
    assert status.get('phase') == 'Running' and any(item['type'] == 'Ready' and item['status'] == 'True'
                                                    for item in status.get('conditions', [])), 'Pod sandboxed must be running and ready'
    sandbox = pod_sandbox(TENANT, 'sandboxed')
    assert sandbox.get('runtimeHandler') == 'runsc', 'containerd must run the Pod sandbox with the runtime handler runsc'
    kernel_log = kubectl('-n', TENANT, 'exec', 'sandboxed', '--', 'dmesg')
    assert 'Starting gVisor' in kernel_log, 'dmesg inside the Pod must show the gVisor kernel log'
    pod_kernel = kubectl('-n', TENANT, 'exec', 'sandboxed', '--', 'uname', '-r')
    node_kernel = node_exec(NODE, 'uname', '-r').stdout.strip()
    assert pod_kernel != node_kernel, 'The Pod must not see the kernel version of the node'
    shuttle = pod_sandbox('starfleet-034-030-01-04', 'shuttle')
    assert shuttle.get('runtimeHandler', '') in ('', 'runc'), 'Pods without a RuntimeClass must keep the default handler'
