address=get('service','probe')['spec']['clusterIP']
assert 'version=v1' in kubectl('-n','starfleet-034-030-01-01','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+'/'), 'Keep the denied target healthy'
if wants('default-deny-policy'):
    behavior_check({'args':['kubectl','-n','tenant-a-034-030-01-01','exec','tenant-reader','--','wget','-q','-T','3','-O-','http://'+address+'/'],'denied':True,'failure_markers':['timed out']})
