# KijaniKiosk Week 4 Security Decisions: Infrastructure as Code

**Prepared for:** Nia (CTO)  
**Date:** Week 4, Friday  
**Author:** Maryann Mwikali

## Summary

This week KijaniKiosk moved from manually provisioned infrastructure to a fully automated Infrastructure-as-Code pipeline. Servers, network controls, authentication requirements, and service hardening are now defined as repeatable configurations rather than relying on manual changes. This improves consistency, reduces configuration drift, and makes security decisions easier to review and audit.

The pipeline provisions three application servers using a consistent baseline and applies the same security model to each environment. A second execution produces no unintended infrastructure or configuration changes, demonstrating that the desired state can be repeatedly enforced.

## Why Automation Changes the Security Posture

Manual hardening introduces configuration drift. A firewall rule added temporarily during troubleshooting may remain indefinitely, permissions changed to resolve an operational problem may never be restored, and different servers can gradually develop different security configurations.

Infrastructure as Code reduces this risk by defining the intended environment centrally and applying it consistently. The same infrastructure configuration creates the servers, network controls, and security boundaries each time. Configuration management then applies the required operating-system and service controls.

Idempotent execution is particularly important. When the pipeline is executed again, resources that already match the intended configuration are not unnecessarily changed. This provides evidence that the infrastructure has converged on its desired state. If a manual modification creates configuration drift, a subsequent deployment can identify and correct the deviation.

## Infrastructure Security Decisions

The infrastructure layer provides the first security boundary around KijaniKiosk. Cloud-level security controls restrict inbound traffic before requests reach the operating system. Administrative access is limited to the approved operator address rather than being exposed broadly to the internet.

Application services are not directly exposed through their individual service ports. Public web traffic enters through the intended web-facing interface, while application communication remains within the server's internal boundaries. This reduces the number of externally reachable attack surfaces.

Authentication uses an SSH key pair rather than password-based access. The private authentication material is kept outside the infrastructure configuration and is referenced rather than embedded in the code. This reduces the likelihood of credentials being accidentally committed to source control or exposed through deployment configuration.

Terraform state is stored remotely with encryption and state locking enabled. Encryption helps protect infrastructure information stored in the state, while locking prevents conflicting infrastructure operations from modifying the same state simultaneously.

## Server and Service Security Decisions

After infrastructure provisioning, configuration management applies the operating-system hardening profile to each server. Services operate using dedicated identities rather than privileged administrative accounts. These identities do not provide interactive login capability, limiting the opportunities for an attacker to use a compromised service as a general-purpose operating-system account.

Systemd hardening further reduces the privileges available to application processes. Services operate with a read-only view of the filesystem except where writing is explicitly required, primarily for application logging. They receive isolated temporary storage, reducing the possibility of one service accessing temporary information belonging to another.

Operating-system capabilities are also restricted. Removing unnecessary capabilities reduces the opportunities available to an attacker who obtains code execution within an application. The objective is not to assume that applications cannot be compromised, but to ensure that a compromised application has as little authority as possible.

Configuration is similarly protected. Application services can read the configuration required for operation but cannot modify their own configuration. This prevents a compromised process from changing its settings to weaken security controls, redirect traffic, or establish persistence.

The payments service receives particular attention because it handles financial transactions and therefore represents a higher-value target. Separating service identities and permissions also limits the potential for compromise of one service to become a straightforward path into another.

## Control Summary

| Control | What it does | Risk mitigated |
|---|---|---|
| SSH restricted to operator address | Cloud firewall limits administrative connections to the approved source address. | Reduces brute-force and unauthorized remote administration attempts. |
| No direct application port exposure | Only the intended web-facing interface is publicly reachable while application ports remain internal. | Reduces external attack surface and prevents direct access to application services. |
| Encrypted remote state with locking | Infrastructure state is stored remotely with encryption and concurrent-access protection. | Reduces exposure of infrastructure information and prevents conflicting state changes. |
| Key pair managed outside the pipeline | Authentication credentials are referenced by the infrastructure configuration without embedding private key material. | Reduces accidental credential exposure through source control or deployment logs. |
| Dedicated service accounts with no shell | Each service runs under its own restricted identity without interactive login capability. | Limits privilege escalation and lateral movement following service compromise. |
| Read-only filesystem for services | Service processes cannot modify the operating system except in explicitly permitted locations. | Reduces backdoor installation, system tampering, and persistence opportunities. |
| Private temporary storage per service | Each service receives isolated temporary resources. | Reduces cross-service information leakage and interference. |
| Restricted operating-system capabilities | Services are prevented from using unnecessary elevated capabilities. | Reduces the potential impact of code execution and privilege escalation. |
| Protected configuration | Services can read required configuration but cannot modify their own security-sensitive settings. | Prevents compromised services from weakening controls or redirecting application behavior. |
| Automated idempotent pipeline | Infrastructure and hardening are repeatedly enforced from a known configuration. | Reduces configuration drift and inconsistent security settings between servers. |

## Current Gaps and Limitations

The current posture primarily protects the infrastructure and operating-system layers. It does not guarantee that the application code or its dependencies are secure. A vulnerability in business logic, authorization, an application dependency, or a database query could still be exploited within the permissions available to the affected service. Secrets are not yet automatically rotated, and the pipeline does not provide comprehensive secrets management. There is also no centralized security monitoring, intrusion detection, or automated alerting for suspicious activity. An attacker operating within the legitimate permissions of a compromised service could therefore potentially access or exfiltrate data without triggering a current security control. The next security investments should include application security testing, dependency scanning, centralized secrets management, automated credential rotation, centralized log forwarding, and network-level anomaly detection.