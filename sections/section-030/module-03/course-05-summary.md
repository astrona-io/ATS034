---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Summary

A dedicated node needs four settings that work together. The node carries a label and a taint. The tenant Pod carries a node selector and a toleration. The selector attracts, the taint repels other Pods, and the toleration only permits. The effect `NoSchedule` blocks new Pods, `PreferNoSchedule` is a soft hint, and `NoExecute` also evicts running Pods. A toleration with no key and the operator `Exists` tolerates every taint.

A node can set most labels on its own Node object. The NodeRestriction admission plugin stops a kubelet from setting labels in the prefix `node-restriction.kubernetes.io/`, and the Node authorizer limits what a kubelet can read and write. Isolation labels use that prefix, and tenants have no rights to update or patch nodes.

Tenants write the Pod fields, so placement must be enforced at admission. The PodNodeSelector and PodTolerationRestriction plugins use namespace annotations, but an administrator must enable them with an API server flag. A ValidatingAdmissionPolicy can reject Pods that lack the required selector, and it needs a binding and a few seconds to take effect.

Each boundary stops a different threat. Namespaces and policy stop interference and API abuse. Sandboxes stop kernel exploits from container code. Dedicated nodes separate machines. Separate clusters separate the control plane. Host paths, DaemonSets, shared storage and the control plane cross a node boundary, so the choice starts from the threat.

- Selector, taint, toleration and node label are four separate jobs.
- Use protected label names for isolation.
- A tenant who writes the Pod can omit its fields, so enforce them at admission.
- No single layer is the whole boundary.

<!-- astrona:playground:destroy -->
