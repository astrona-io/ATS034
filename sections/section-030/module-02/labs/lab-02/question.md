---
draft: true
---
# Run A Workload Under gVisor

Solve this question on: `terminal`

Connect with `astrona ssh ats-034-lab-030-02-02`. The VM has Docker, checksum-verified gVisor binaries under `/usr/local/bin`, and the image `busybox:1.37.0`. Docker has not registered `runsc`. The web content `/srv/scout/index.html` contains `scout-ready`.

Allow about 15 minutes for the tasks. VM startup and downloads add time.

## Tasks

1. Register `/usr/local/bin/runsc` as the Docker runtime `runsc`, using the `systrap` platform, and restart Docker. Prove a fresh container starts with this runtime.
2. Start container `scout` with `runsc` and `busybox:1.37.0`. Serve `/srv/scout` read-only at `http://127.0.0.1:8080/` using BusyBox httpd. Check the configured runtime, the gVisor kernel log and the HTTP response.

## Constraints

Keep the provided binaries, image, web content and grader tools unchanged. The service must remain available. Use gVisor's application kernel; naming an ordinary runc container `runsc` does not satisfy the task.

## How the answer is checked

The grader checks the registered executable and its checksum, launches a fresh sandbox, inspects the workload runtime and tests the live HTTP response. This proves runtime selection and operation in this fixture; it is not a penetration test or proof against every escape technique.
