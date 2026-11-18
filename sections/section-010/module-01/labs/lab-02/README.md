---
exam_objectives:
- Use appropriate pod security standards
---
# Run A Pod That Meets Restricted With A Read-Only Root

Write a Pod that meets the Restricted profile, runs as user 1000 and has a read-only root filesystem with one writable emptyDir volume. The graders read /proc/1/status in the container and try real writes. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
