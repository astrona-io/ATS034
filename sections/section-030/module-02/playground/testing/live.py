behavior_check({'args':['kubectl','-n','tenant-b','get','pod','sandboxed-app','-o','jsonpath={.spec.nodeName}'],'equals':'astro-ats-034-playground-030-02-worker'})
