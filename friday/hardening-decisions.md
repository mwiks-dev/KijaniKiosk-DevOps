# Hardening Decisions for the KijaniKiosk Provisioning System

## Introduction

The KijaniKiosk provisioning script was designed using the principle of **defence in depth**, where several security controls work together instead of relying on a single protection mechanism. The objective was to create an idempotent provisioning script that could safely configure a Linux server regardless of whether it was a clean installation or an existing server with partially configured services. During development, the environment already contained service accounts, ACLs, firewall rules, systemd services and application directories. Instead of assuming a fresh machine, the script reconciles the existing configuration into the desired secure state.

Another guiding principle was **least privilege**. Every service receives only the permissions it requires to perform its own tasks. Configuration files remain protected by the root account, application services are isolated from each other, and only carefully controlled sharing is permitted where collaboration is required, such as the shared logging directory. The final design combines Linux permissions, ACLs, systemd security directives, firewall rules, journal persistence, log rotation and verification checks to create multiple layers of protection.

---

## Major Hardening Decisions

| Decision                               | Why it was chosen                                                                                             | Security Benefit                                                      |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Dedicated service accounts             | Each application runs as its own Linux user instead of root.                                                  | Limits the impact if one service is compromised.                      |
| Root-owned configuration files         | Environment files remain owned by root while services receive read-only access through the kijanikiosk group. | Prevents services from modifying secrets or configuration files.      |
| Service directory isolation            | API, payments and logging directories have separate ownership and permissions.                                | Stops one service from accessing another service's application files. |
| Shared logging with ACLs               | Multiple services need controlled access to shared log files.                                                 | Allows collaboration without making directories world writable.       |
| SGID on the shared log directory       | Ensures newly created files inherit the logging group automatically.                                          | Prevents permission problems after new log files are created.         |
| systemd hardening                      | Services use sandboxing and privilege restrictions.                                                           | Reduces the operating system resources available to an attacker.      |
| Default-deny firewall                  | Only required network ports are opened.                                                                       | Reduces unnecessary network exposure.                                 |
| Persistent journaling and log rotation | System logs survive reboot and are automatically rotated.                                                     | Improves troubleshooting while preventing logs from filling the disk. |
| Health monitoring                      | Provisioning creates a structured JSON health report.                                                         | Allows monitoring tools to verify deployment status automatically.    |
| Verification phase                     | Every provisioning phase is validated before completion.                                                      | Detects configuration errors immediately.                             |

---

## File System Protection

The provisioning script carefully separates application data according to its purpose. The API, payments and logging directories each have their own owner and group, with permissions set to **750**. This means that only the owning service account has full access while other users cannot browse or modify the application files.

The configuration directory is owned by **root:kijanikiosk** with directory permissions of **750** and configuration files using **640** permissions. This prevents application services from changing configuration values while still allowing them to read the environment variables required during startup. Using group-based access simplifies administration because every authorised service account belongs to the same application group.

The shared logging directory requires more flexibility because multiple services write or read log files. Standard Linux permissions alone cannot satisfy these requirements, so Access Control Lists (ACLs) were used together with the SGID bit. The SGID permission ensures that newly created files automatically inherit the logging group, while default ACLs grant the API and payments services access to newly created log files. This design removes the need to manually repair permissions after log files are created or rotated.

---

## Service Isolation with systemd

Each application component runs as an independent systemd service rather than sharing a common process. This separation improves reliability while also increasing security.

The unit files use several hardening directives including **NoNewPrivileges**, **ProtectSystem**, **ProtectHome**, **PrivateTmp**, **PrivateDevices**, **ProtectKernelTunables**, **ProtectKernelModules**, **ProtectControlGroups**, **RestrictRealtime**, **RestrictSUIDSGID**, **LockPersonality**, **CapabilityBoundingSet**, **AmbientCapabilities**, and **SystemCallFilter**. These directives remove unnecessary operating system privileges and reduce the number of system resources each service can access.

The payments service receives additional protection because it processes financial transactions. It depends on the API service through the **After=kk-api.service** and **Wants=kk-api.service** directives, ensuring the correct startup order. Additional restrictions such as **ReadOnlyPaths**, **ReadWritePaths**, **RestrictAddressFamilies**, and **InaccessiblePaths** further limit filesystem and network access. These extra controls reflect the higher sensitivity of payment processing compared to the other services.

---

## Network Security

Network access is restricted using the Uncomplicated Firewall (UFW). The firewall follows a **default deny** policy for incoming connections while allowing all outgoing traffic. Only the ports required by the application are opened.

SSH remains available for system administration, while HTTP is opened to allow incoming web traffic. Additional monitoring rules can be added for internal health checks where required. Restricting unnecessary network access reduces the server's attack surface and limits opportunities for unauthorised connections.

---

## Logging and Monitoring

Reliable logging is essential for both troubleshooting and security investigations. The provisioning script enables persistent systemd journals by configuring storage under **/var/log/journal** with a maximum size of **500 MB**. This allows logs to survive system reboots while preventing uncontrolled disk usage.

A dedicated logrotate configuration automatically rotates application logs, compresses older files and retains a limited history. The configuration recreates new log files using the correct ownership and permissions. Because the shared logging directory uses default ACLs, newly created files automatically inherit the required access permissions after every rotation. This ensures the access model remains consistent without requiring manual intervention.

The provisioning process also generates a structured health report in **/opt/kijanikiosk/health/last-provision.json**. The report records the timestamp together with the status of the API and payments services. Even when application code has not yet been deployed, the health report correctly records the services as **"down"**, demonstrating that the monitoring process itself is functioning correctly.

---

## Verification Strategy

A major design decision was to verify every configuration phase instead of assuming success. After provisioning completes, the script confirms that packages are installed and held, service accounts exist, directories have the correct ownership, ACLs are present, environment files are readable, firewall rules exist, journaling is persistent, logrotate passes validation and the health report has been created with the correct ownership and permissions.

If any verification step fails, the script exits with a non-zero status and reports exactly which checks passed and which failed. This makes troubleshooting much easier and supports repeatable deployments.

---

## Honest Gaps

Although the final solution provides multiple layers of protection, it is not a complete production security platform. Configuration secrets are still stored in environment files rather than a dedicated secrets management solution such as HashiCorp Vault. The health checks verify only service port availability rather than performing application-level API checks. Centralised log aggregation has not been implemented, meaning logs remain on the local server. The solution also does not include intrusion detection, vulnerability scanning or automated security patch management.

Finally, system hardening protects the operating environment but cannot prevent vulnerabilities inside the application code itself. Secure software development practices, regular patching and continuous monitoring would still be required before deploying this system into a real production environment.

---

## Conclusion

The KijaniKiosk provisioning solution demonstrates a layered approach to Linux system security by combining service isolation, least privilege, filesystem permissions, ACLs, firewall controls, systemd sandboxing, persistent logging, automated log rotation and comprehensive verification. Rather than depending on a single defence mechanism, each layer complements the others to produce a repeatable and secure deployment process. The resulting script can safely reconcile both clean and partially configured servers into the required secure state while remaining maintainable, idempotent and suitable for continued development.
