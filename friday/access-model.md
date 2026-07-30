# KijaniKiosk Access Model — Final (Friday)

Updated from Tuesday's access model to include the Health directory (Phase 8) and Journal/Logrotate integration (Phase 7).

---

# Service Accounts

| Account | Type | Shell | Home | Group Memberships | Purpose |
|---------|------|-------|------|-------------------|---------|
| kk-api | System | /usr/sbin/nologin | /home/kk-api | kk-api, kijanikiosk | Runs the API service |
| kk-payments | System | /usr/sbin/nologin | /home/kk-payments | kk-payments, kijanikiosk | Runs the Payments service |
| kk-logs | System | /usr/sbin/nologin | /home/kk-logs | kk-logs, kijanikiosk | Owns the shared logging infrastructure and health reports |
| amina | Regular User | /bin/bash | /home/amina | amina, kijanikiosk | Administrative user with group access to shared application resources |

---

# Directory Access Model

| Directory / File | Owner : Group | Mode | Access Model | Security Reasoning |
|------------------|---------------|------|--------------|--------------------|
| /opt/kijanikiosk/api | kk-api : kk-api | 750 | Basic UGO | Only the API service account has full control over its application files. |
| /opt/kijanikiosk/payments | kk-payments : kk-payments | 750 | Basic UGO | Isolates the Payments service from the API and logging components. |
| /opt/kijanikiosk/logs | kk-logs : kk-logs | 750 | Basic UGO | Dedicated log directory owned by the logging service. |
| /opt/kijanikiosk/config | root : kijanikiosk | 750 | Basic UGO | Configuration directory owned by root while remaining accessible to authorized application services. |
| /opt/kijanikiosk/config/*.env | root : kijanikiosk | 640 | Basic UGO | Environment files remain read-only to the application group and writable only by root. |
| /opt/kijanikiosk/scripts | root : kijanikiosk | 750 | Basic UGO | Administrative scripts are protected from modification by service accounts while remaining executable when required. |
| /opt/kijanikiosk/shared/logs | kk-logs : kk-logs | 2770 | SGID + Default ACLs | Central shared logging directory. SGID ensures new files inherit the logging group while ACLs provide controlled access for other services. |
| /opt/kijanikiosk/health | kk-logs : kijanikiosk | 750 | Basic UGO | Stores provisioning and monitoring output. Writable only by the logging service while readable by the application group. |
| /opt/kijanikiosk/health/last-provision.json | kk-logs : kijanikiosk | 640 | Basic UGO | Structured health report generated during provisioning and readable by authorized services. |

---

# Default ACL Configuration for Shared Logs

```
# getfacl /opt/kijanikiosk/shared/logs

# owner: kk-logs
# group: kk-logs

user::rwx
user:kk-api:rwx
user:kk-payments:r-x
group::rwx
mask::rwx
other::---

default:user::rwx
default:user:kk-api:rwx
default:user:kk-payments:r-x
default:group::rwx
default:mask::rwx
default:other::---
```

## Why Default ACLs?

The shared log directory is accessed by multiple services with different responsibilities.

- **kk-logs** owns and manages the directory.
- **kk-api** writes application log files.
- **kk-payments** reads shared logs for monitoring and audit purposes.
- Other users have no access.

Using default ACLs ensures every new file created inside the directory automatically receives the required permissions.

---

# Logrotate Integration

The provisioning script creates the following Logrotate configuration:

```text
create 0660 kk-logs kijanikiosk
su kk-logs kijanikiosk
```

When Logrotate executes:

1. The current log file is rotated.
2. A new empty log file is created with ownership **kk-logs:kijanikiosk** and mode **0660**.
3. Because `/opt/kijanikiosk/shared/logs` has default ACLs, the new file automatically inherits the required ACL entries.
4. The SGID bit ensures new files continue to inherit the logging group.

This guarantees that log rotation does not break the application's access model.

---

# Verification After Log Rotation

The provisioning process verifies that the access model survives log rotation.

```bash
sudo logrotate --force /etc/logrotate.d/kijanikiosk

sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp \
    && echo "PASS: kk-api can write after logrotate" \
    || echo "FAIL: kk-api cannot write after logrotate"

rm -f /opt/kijanikiosk/shared/logs/test-write.tmp
```

A successful write confirms that:

- SGID inheritance is functioning.
- Default ACLs are correctly applied.
- Logrotate creates replacement files with compatible ownership and permissions.

---

# Health Directory Design

The Health directory is introduced in Friday's provisioning process to store structured provisioning results.

### Ownership

- **Owner:** `kk-logs`
- **Group:** `kijanikiosk`

### Permissions

Directory:

```text
750
```

Health report:

```text
640
```

### Design Rationale

- The provisioning script generates `last-provision.json` after completing health checks.
- The file is then assigned to `kk-logs:kijanikiosk`.
- Members of the `kijanikiosk` group can read the report.
- Only the owner (`kk-logs`) can modify it.
- No ACLs are required because only one service writes to the file while multiple authorized users read it.

---

# Overall Security Model

The final access model combines multiple Linux security mechanisms:

- Traditional Unix ownership (UGO)
- Dedicated service accounts
- Least-privilege directory permissions
- SGID for shared logging
- Default ACL inheritance
- Root-owned configuration files
- Controlled group-based access
- Logrotate compatibility
- Structured health reporting

Together these mechanisms ensure that services receive only the permissions they require while preserving correct operation after provisioning, service restarts, and log rotation.