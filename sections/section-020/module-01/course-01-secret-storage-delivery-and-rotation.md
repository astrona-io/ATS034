---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Secret Storage, Delivery And Rotation

A database stops accepting its old password before every consumer adopts the replacement. The Secret update succeeded, yet requests fail. Credential rotation must coordinate the issuer, stored value, delivery method and running consumers.

## Learning objectives

- Explain why Secret encoding is not encryption.
- Compare environment and mounted-file update behavior.
- Identify authorization and diagnostic exposure risks.

## Before you start

This chapter is standalone reading material; no running cluster or installed tools are required. A Pod is the Kubernetes unit for running one or more containers, and a namespace groups namespaced objects. Treat the worked configurations as teaching examples rather than recorded observations from a provisioned environment.

## Responsible components and behavior

The `scout` application uses a non-sensitive log level and a sensitive database password. A ConfigMap stores configuration data that is not intended to be secret. A Secret is a Kubernetes resource for sensitive data. Keeping both outside the image lets the same application artifact run with different deployment settings.

A Pod can receive values through environment variables or files mounted from a volume. Environment variables are set when the container starts; updating the source object does not rewrite the environment of that running process. Mounted configuration files can receive updates after a delay, but the application must notice or reload them. A mount using `subPath` does not receive those automatic volume updates.

A Secret's base64 representation is an encoding, not encryption. Access control, encryption at rest and careful application behavior are separate protections. A person allowed to read a Secret can obtain its contents, and a process can accidentally expose a password by writing it to logs. The resource type alone does not make all handling safe.

Configuration needs a lifecycle plan. If an application only reads a file during startup, changing the ConfigMap requires a restart or rollout to activate the new value. If it supports reload, verify that the reload occurred. For password rotation, consider when the external database begins accepting the new value and when clients stop using the old one.

Suppose the log level changes but the application keeps its previous verbosity. First identify whether it reads an environment variable, a mounted file or a cached value. The correct explanation depends on how the data reaches the process, not just on whether the Kubernetes object was updated.

## Configuration As A Process Input

Imagine `scout` reads a log level at startup and checks a configuration file for a feature setting during each request. Updating the ConfigMap can affect these two settings differently. The startup environment remains the same until a new process receives different values. A supported mounted-file update can become visible later, but only the application logic determines when the new setting is used.

A file update is therefore only one stage. Delivery changes the mounted data; adoption changes the application's effective behavior. An application that reads once and caches the result needs an explicit reload or restart even if its file changed correctly. An application that watches files needs to handle the update mechanism and avoid reading inconsistent intermediate state.

Separating configuration from an image supports reuse, but it also creates a compatibility contract. Version two may require a new key that version one never used. A rollout containing both versions can need settings valid for both. A missing required key should produce a clear error rather than a silently unsafe default.

## Rotating Sensitive Values

For a database password, identify the issuer, the stored Secret, the delivery method and each consumer. If the database stops accepting the old password before all clients adopt the new one, requests can fail. If the old password remains valid forever, rotation has not removed its exposure.

Environment-based consumers generally need new containers to receive new values. File-based consumers may need application reload. In both cases, readiness and representative requests should confirm that consumers can use the updated credential. Avoid logging the password as proof of adoption; verify authentication behavior without exposing the secret.

A Secret also needs protections beyond its resource name. Read access can reveal the credential, container access can expose mounted files and diagnostic bundles can copy them unintentionally. Handle sensitivity through permissions, storage encryption and application behavior, while preserving a clear plan for how updates become effective.

## Work through the decision

A Secret is a resource for sensitive data, but its serialized base64 data is encoding rather than encryption. API permissions, storage encryption and consumer behavior protect different exposure paths. Avoid retrieving full Secret YAML simply to establish that a named object exists.

Rotation is a sequence of changes across systems. The issuer must accept the replacement, consumers must receive and adopt it, and the earlier value must eventually lose authority. Updating the Kubernetes object alone does not update an existing process environment or revoke the credential at its issuer. Verification should test intended access and the planned retirement behavior without printing the value.

```mermaid
flowchart TB
    I["Issuer accepts replacement"] --> S["Stored Secret update"]
    S --> D["Consumer delivery"]
    D --> A["Application adoption"]
    A --> V["Access verification"]
    V --> R["Earlier authority retired"]
```

Rotation becomes effective through coordinated adoption and retirement, rather than through one stored update.

You can now describe safe credential verification without using disclosure as evidence. Each rotation plan must state how consumers adopt updates and when old authority is removed.

## Common pitfalls

> [!WARNING]
> Updating a ConfigMap or Secret does not automatically replace environment variables in running containers. Base64 data in a Secret is not encrypted merely because it is encoded.
