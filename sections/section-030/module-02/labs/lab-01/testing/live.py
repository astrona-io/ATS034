behavior_check({'args':['kubectl','-n','tenant-b','get','pod','sandboxed-app','-o','jsonpath={.spec.nodeName}'],'equals':'astro-ats-034-lab-030-02-01-worker'})
