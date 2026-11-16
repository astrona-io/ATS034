address=get('service','probe')['spec']['clusterIP']
assert 'version=v1' in kubectl('-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+'/'), 'Keep the denied target healthy'
behavior_check({'args':['kubectl','-n','untrusted','exec','job-runner','--','wget','-q','-T','3','-O-','http://'+address+'/'],'denied':True,'failure_markers':['timed out']})
behavior_check({'args':['kubectl','-n','untrusted','run','plain','--image=docker.io/library/busybox:1.37.0','--restart=Never','--dry-run=server','--overrides={"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"plain","image":"docker.io/library/busybox:1.37.0","command":["sleep","60"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'],'denied':True,'failure_markers':['pods must set runtimeclassname sandboxed']})
# The API server drops an empty rule list, so check that no rule allows traffic.
spec = get('networkpolicy', 'untrusted-isolation', namespace='untrusted')['spec']
assert not spec.get('ingress'), 'untrusted-isolation must not allow any ingress'
assert not spec.get('egress'), 'untrusted-isolation must not allow any egress'
