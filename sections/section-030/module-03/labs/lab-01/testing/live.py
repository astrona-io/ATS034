behavior_check({'args':['kubectl','-n','tenant-c','get','pods','-l','app=tenant-c-app','-o','jsonpath={.items[0].spec.nodeName}'],'equals':'astro-ats-034-lab-030-03-01-worker'})
