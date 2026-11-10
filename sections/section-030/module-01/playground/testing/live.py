address=get('service','probe')['spec']['clusterIP']
assert 'version=v1' in kubectl('-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+'/'), 'Keep the denied target healthy'
behavior_check({'args':['kubectl','-n','tenant-a','exec','tenant-reader','--','wget','-q','-T','3','-O-','http://'+address+'/'],'denied':True,'failure_markers':['timed out']})
# The API server drops an empty rule list, so check that no rule allows traffic.
spec = get('networkpolicy', 'tenant-isolation', namespace='tenant-a')['spec']
assert not spec.get('ingress'), 'tenant-isolation must not allow any ingress'
assert not spec.get('egress'), 'tenant-isolation must not allow any egress'
