# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. Capstones combine selected skills and do not silently count as coverage of every reading.

## Live assessment additions

New QEMU labs run a workload under the actual gVisor runtime and observe Cilium WireGuard traffic between two Kubernetes nodes. The WireGuard grader compares plaintext on the tunnel interface with encrypted outer traffic.

## Remaining practical gaps and boundaries

- The original RuntimeClass lab demonstrates handler selection. The separate gVisor VM provides runtime execution evidence; its diagnostic banner is not a security attestation.
- WireGuard tests cover cross-node Pod traffic, not same-node traffic, external endpoints or node encryption. Live IPsec key rotation remains ungraded.
- Encryption-at-rest rotation, external secret services and encrypted Git workflows remain reference or playground material.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
