# Encrypt And Authorize Pod Traffic Capstone

This graded capstone combines three skills in one cluster: requiring mTLS for a namespace with a `PeerAuthentication`, allowing only one workload identity with an `AuthorizationPolicy`, and preparing the Helm values that turn on Cilium WireGuard encryption between nodes. The cluster does not run Cilium, so the grader reads the values file.

Start the cluster with the starting state in place:

```bash
astrona run --git git@github.com:astrona-io/ATS034.git -c sections/section-040/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-034-capstone-040
```

Run `testing/smoke.sh` with the private kubeconfig to verify that the starting state fails grading and that the reference result passes. Runtime verification has not been recorded yet.
