# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. Capstones combine selected skills and do not silently count as coverage of every reading.

## Remaining practical gaps and boundaries

- The RuntimeClass lab uses `runc` and grades handler selection, scheduling and overhead. It does not run gVisor or Kata or prove an additional sandbox boundary.
- The Cilium lab grades IPsec key syntax and intended values. It does not install Cilium, encrypt packets or rotate a live IPsec key. Istio labs do test live mTLS traffic.
- Encryption-at-rest setup, external secret stores and encrypted Git workflows are reference procedures without dedicated labs in this course.

These are explicit limits, not completed assessments. When closing one, add or extend a runnable environment, teach the actual commands and evidence, add a live grader with negative cases, and update the mapping. Do not mark a reference procedure as practiced just because it contains a command block.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
