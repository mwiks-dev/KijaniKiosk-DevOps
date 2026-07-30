# Integration Challenge Notes

## Friday Production Provisioning – Integration Challenges

This document explains how the four major integration challenges were resolved while building the production provisioning script for KijaniKiosk. Each section describes the conflict encountered, the options considered, the implementation chosen, and the reasoning behind that decision.

---

# Integration Challenge 1: Supporting a Dirty Existing Environment

## Conflict

The provisioning script was required to run successfully on a virtual machine that already contained partially configured resources. Users, groups, systemd services, ACLs, held packages, firewall rules, and application directories already existed. A script written only for a clean installation would either fail or produce duplicate configuration.

## Options Considered

### Option 1 – Assume a clean system

Create every resource without checking whether it already existed.

**Rejected**

This approach causes failures when users, groups or directories already exist and is not idempotent.

### Option 2 – Reconcile the existing state

Check the existing system before making changes and only create or modify resources when necessary.

**Chosen**

## Resolution

The provisioning script performs existence checks before every major operation.

Examples include:

* `id` before creating service accounts
* `getent group` before creating the application group
* `mkdir -p` for directory creation
* `usermod -aG` for group membership
* overwriting systemd unit files before running `daemon-reload`
* reconciling ACLs using `setfacl`
* checking held packages before installation

The firewall configuration was also updated rather than assuming a completely empty ruleset.

## Why this approach

This makes the script idempotent. Running it multiple times produces the same final system state without generating duplicate resources or errors.

---

# Integration Challenge 2: Preserving the Access Model During Log Rotation

## Conflict

The shared logging directory uses SGID and ACLs to allow multiple services to access the same logs.

When logrotate creates a new log file after rotation, incorrect ownership or permissions would prevent services from writing to or reading the replacement log file.

## Options Considered

### Option 1 – Standard logrotate configuration

Use only the default `create` directive.

**Rejected**

This does not work correctly with an SGID directory and causes logrotate to refuse rotation because the directory is group writable.

### Option 2 – Configure logrotate to match the access model

Use:

* `su kk-logs kk-logs`
* `create 0660 kk-logs kk-logs`

while relying on the directory's default ACLs.

**Chosen**

## Resolution

The logrotate configuration now explicitly specifies:

```text
su kk-logs kk-logs
create 0660 kk-logs kk-logs
```

The directory itself remains:

```
Owner: kk-logs
Group: kk-logs
Mode: 2770
```

Default ACLs automatically propagate permissions to new files after rotation.

The implementation was verified by:

* running `logrotate --debug`
* forcing a rotation
* confirming ACL inheritance
* verifying that `kk-api` could still create files in the shared log directory after rotation.

## Why this approach

This keeps the logging permissions consistent before and after rotation while allowing logrotate to operate safely inside an SGID directory.

---

# Integration Challenge 3: Balancing Security Hardening with Service Availability

## Conflict

The production services needed aggressive systemd hardening while still remaining capable of starting correctly.

Adding every available hardening directive improves the security score but can also prevent the service from functioning.

## Options Considered

### Option 1 – Maximise hardening regardless of functionality

Apply every available hardening directive.

**Rejected**

Several directives can prevent a Node.js application from starting or accessing required resources.

### Option 2 – Apply only tested hardening

Incrementally introduce security directives while verifying that the service still starts correctly.

**Chosen**

## Resolution

Each service uses a hardened systemd unit containing directives such as:

* NoNewPrivileges
* ProtectSystem
* ProtectHome
* PrivateTmp
* PrivateDevices
* CapabilityBoundingSet=
* AmbientCapabilities=
* RestrictSUIDSGID
* RestrictRealtime
* ProtectKernelTunables
* ProtectKernelModules
* SystemCallArchitectures
* SystemCallFilter
* MemoryDenyWriteExecute
* LockPersonality

The payments service received additional restrictions because it processes financial data.

Potentially disruptive directives such as `DynamicUser` and `PrivateNetwork` were investigated but intentionally omitted because they conflicted with the established access model and service communication requirements.

## Why this approach

The final configuration achieves strong security while remaining operational and maintainable.

---

# Integration Challenge 4: Monitoring Before Application Deployment

## Conflict

The provisioning script was required to generate health monitoring information even though the application code might not yet be deployed.

Simply checking service ports would fail because no services would be listening.

## Options Considered

### Option 1 – Fail provisioning when ports are closed

Treat missing listeners as provisioning failures.

**Rejected**

The infrastructure may be correctly configured even when application code has not yet been deployed.

### Option 2 – Record the observed state

Always generate a health report indicating whether each port is currently reachable.

**Chosen**

## Resolution

The provisioning script performs TCP checks against:

* Port 3000
* Port 3001

using Bash TCP redirection and `timeout`.

The results are written to:

```
/opt/kijanikiosk/health/last-provision.json
```

Example:

```json
{
  "timestamp":"2026-07-30T14:05:00+03:00",
  "kk-api":"down",
  "kk-payments":"down"
}
```

The script then assigns:

* Owner: `kk-logs`
* Group: `kijanikiosk`
* Permissions: `640`

The verification phase confirms:

* the file exists
* ownership is correct
* permissions are correct
* required JSON fields are present

## Why this approach

The health report always reflects the real system state. Infrastructure verification succeeds while clearly indicating whether the application services are running.

---

# Summary

The final provisioning solution integrates security, idempotency, logging, monitoring, and access control into a coherent deployment process. Rather than treating each requirement independently, the implementation reconciles interactions between ACLs, systemd hardening, firewall rules, log rotation, persistent journaling, and health monitoring. The result is a provisioning script that can be safely rerun on an existing system, produces a predictable end state, and verifies that all major components of the deployment remain correctly configured.
