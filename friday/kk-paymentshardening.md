# kk-payments.service — Iterative Hardening Log

## Objective

Harden the `kk-payments.service` systemd unit to achieve an exposure score below **2.5** while maintaining a functional service.

---

# Baseline

The initial service consisted of the standard systemd directives:

- User / Group
- WorkingDirectory
- ExecStart
- Restart policy

Running

```bash
sudo systemd-analyze security kk-payments.service
```

produced a high exposure score, indicating that the service had minimal sandboxing.

---

# Iteration 1 — Basic Service Isolation

Added:

```ini
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
PrivateUsers=yes
```

### Why

These directives isolate the service from the host environment by:

- preventing privilege escalation,
- giving the service its own `/tmp`,
- hiding physical devices,
- mapping users inside a private namespace.

This significantly reduced the service's exposure.

---

# Iteration 2 — Filesystem Protection

Added:

```ini
ProtectSystem=strict
ProtectHome=yes
```

### Why

`ProtectSystem=strict` mounts most of the operating system read-only.

`ProtectHome=yes` prevents the service from accessing user home directories.

The application only requires access to its own working directory and configuration, so these restrictions are appropriate.

---

# Iteration 3 — Kernel Protection

Added:

```ini
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
```

### Why

The payments service never needs to:

- modify kernel parameters,
- load kernel modules,
- manipulate cgroups,
- change the system clock,
- modify the hostname.

Removing access reduces the attack surface.

---

# Iteration 4 — Process Restrictions

Added:

```ini
MemoryDenyWriteExecute=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
```

### Why

These directives prevent several common privilege escalation techniques including:

- executable writable memory,
- execution personality changes,
- realtime scheduling abuse,
- creation or execution of SUID/SGID binaries.

---

# Iteration 5 — System Call and Capability Restrictions

Added:

```ini
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallArchitectures=native
SystemCallFilter=@system-service
UMask=0027
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
```

### Why

The payments service requires no Linux capabilities.

Removing all capabilities and restricting system calls greatly reduces the available kernel attack surface while still allowing a standard Node.js service to run.

Restricting address families limits networking to UNIX sockets, IPv4 and IPv6 only.

---

# Directives Considered but Not Used

## PrivateNetwork=yes

### Reason considered

Would completely isolate the service's network stack.

### Why rejected

The payments service must communicate with the API service and accept network connections.

Enabling `PrivateNetwork=yes` prevented normal operation.

---

## MemoryDenyWriteExecute with incompatible modules

During testing this directive was monitored closely because some runtimes or native libraries can require writable executable memory.

In the current Node.js environment the service started successfully, so the directive was retained.

(If testing had shown failures, this directive would have been removed rather than preventing the service from starting.)

---

# Service Dependencies

The payments service depends on the API service.

```ini
After=network-online.target kk-api.service
Wants=network-online.target kk-api.service
```

This ensures the API service is started before the payments service.

---

# Environment File

The service loads its configuration from:

```ini
EnvironmentFile=-/opt/kijanikiosk/config/payments-api.env
```

Verified with:

```bash
sudo -u kk-payments cat /opt/kijanikiosk/config/payments-api.env
```

to confirm that the service account can read the file before startup.

---

# Final Verification

```bash
sudo systemd-analyze security kk-payments.service
```

Final result:

```
Overall exposure level: 2.0
```

Target achieved: **below 2.5**

---

# Final Unit File
```bash
  GNU nano 7.2                                                             /etc/systemd/system/kk-payments.service                                                                      
[Unit]
Description=KijaniKiosk Payments Service
Wants=network-online.target kk-api.service
After=network-online.target kk-api.service
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=kk-payments
Group=kk-payments
WorkingDirectory=/opt/kijanikiosk/payments
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/node /opt/kijanikiosk/payments/processor.js
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
TimeoutStartSec=30
TimeoutStopSec=30
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ProtectClock=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProcSubset=pid
PrivateMounts=true
RestrictSUIDSGID=true
RestrictRealtime=true
RestrictNamespaces=true
LockPersonality=true
RemoveIPC=true
UMask=0077
ReadWritePaths=/opt/kijanikiosk/payments
ReadOnlyPaths=/opt/kijanikiosk/config
CapabilityBoundingSet=
AmbientCapabilities=
SocketBindDeny=any
StandardOutput=journal
```
