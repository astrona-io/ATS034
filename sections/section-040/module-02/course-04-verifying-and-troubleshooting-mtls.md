---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Verifying And Troubleshooting mTLS

A policy object that says `STRICT` is a declaration, not proof. Proof is an allowed request that works, a denied request that fails for the right reason, and evidence in the proxy that a TLS handshake happened. This part builds that habit and then breaks mTLS on purpose, so you can recognise the most common failure.

## What counts as proof

Three kinds of evidence fit together. The first is behaviour: a client with a sidecar reaches the service, and a client without a sidecar does not. The second is the proxy itself: Envoy counts completed TLS handshakes, and its log shows each failed connection. The third is telemetry: the metric `istio_requests_total` carries the label `connection_security_policy`, which is `mutual_tls` for encrypted requests.

A fourth kind, a packet capture on the node, proves the wire format, and it is the strongest evidence. It needs access to the node, so use it when the other three disagree.

## Test the allowed and the denied path

The commands below need the policies `namespace-strict` and `legacy-permissive` applied in `starfleet`. Send one request from each kind of client:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
```

The first command returns the `version=v1` line. The second fails with a connection error that mentions a reset. Note which component acts: the sidecar of `probe` closes the plain-text connection, and the `probe` application never sees it.

## Read the handshake counters and the log

Ask the sidecar of a `probe` Pod for its TLS statistics:

```sh
kubectl -n starfleet exec deploy/probe -c istio-proxy -- pilot-agent request GET stats | grep ssl.handshake
```

The lines are counters. A value above zero shows that the sidecar completed TLS handshakes with clients. Send the allowed request again and run the command a second time: the counter for the inbound listener grows. Then read the access log of the same sidecar:

```sh
kubectl -n starfleet logs deploy/probe -c istio-proxy --tail=20
```

The log shows each request the sidecar served. The access log of a mesh may be off by default, so an empty log does not prove that no traffic arrived.

## Break mTLS on purpose

The most common failure is a client that sends plain text to a server that requires mTLS. The sidecar of the client decides how to connect, and a `DestinationRule` can override the automatic choice. Save this as `destinationrule-probe-disable-tls.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: probe-disable-tls
  namespace: starfleet
spec:
  host: probe.starfleet.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE
```

Apply it and repeat the request from `shuttle`:

```sh
kubectl apply -f destinationrule-probe-disable-tls.yaml
kubectl -n starfleet exec shuttle -c client -- wget -T 3 -O- http://probe.starfleet.svc.cluster.local/
```

The request now fails, although `shuttle` has a sidecar. The `DestinationRule` tells the client sidecar to send plain text to `probe`, and the sidecar of `probe` rejects it under `STRICT`. The client sidecar usually returns an HTTP 503 error, because its upstream connection ended. The fix is to remove the rule, or to set `tls.mode: ISTIO_MUTUAL` so the client sends mTLS:

```sh
kubectl delete -f destinationrule-probe-disable-tls.yaml
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
```

The request works again. You now have the full cycle: declare, test both paths, read the proxy, and diagnose a client-side setting that conflicts with the server policy.

## Symptoms and causes

| Symptom | Likely cause |
| --- | --- |
| A client without a sidecar gets a connection reset | The server policy is `STRICT`; the client needs a sidecar or an exception |
| A client with a sidecar gets HTTP 503 | A `DestinationRule` disables TLS, or the server sidecar is not ready |
| Handshake counters stay at zero | The traffic does not pass through the sidecar, or the Pod has no sidecar |
| TLS errors after a CA change | The two sides do not trust the same root |
| New Pods fail while old Pods work | The new Pods have no sidecar because injection was not on |

## Common pitfalls

> [!WARNING]
> - **Trusting the policy object as proof.** Always send one allowed and one denied request.
> - **Reading an empty access log as no traffic.** Access logging may be off.
> - **Testing from inside the server Pod.** A request from the application container of the same Pod does not cross the mesh in the way a remote client does.
> - **Leaving a test `DestinationRule` behind.** It changes client behaviour for the whole host.
> - **Debugging the server first.** Check what the client sidecar sends before you change the server policy.
