address=get('service','probe')['spec']['clusterIP']
assert 'version=v1' in kubectl('-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+'/'), 'Keep the denied target healthy'
behavior_check({'args':['kubectl','-n','tenant-a','exec','tenant-reader','--','wget','-q','-T','3','-O-','http://'+address+'/'],'denied':True,'failure_markers':['timed out']})
