---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Starting Environment

The namespaces `untrusted-034-030-02-03` and `trusted-034-030-02-03` exist. The RuntimeClass `sandboxed` uses the handler `runc`, the only runtime handler of this kind cluster, so the lab grades the admission rule and not a real sandbox. The Pod `job-runner` runs in `untrusted-034-030-02-03` with the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep infinity"`, without a `runtimeClassName`. No ValidatingAdmissionPolicy exists.
