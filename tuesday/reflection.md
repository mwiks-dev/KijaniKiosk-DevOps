Here's a complete `reflection.md` that directly answers all four questions with technical reasoning rather than simply describing the commands used.

# Reflection: Linux Permissions

## Question 1: The SUID Paradox

Although modern Linux kernels ignore the SUID bit on shell scripts, the issue is still a legitimate security finding. The kernel ignores SUID on interpreted scripts because of a race condition. When a script is executed, the kernel must first invoke the interpreter (such as Bash), which then opens the script file. An attacker could potentially replace or modify the script between these two operations, causing different code to be executed with elevated privileges. To eliminate this class of vulnerability, Linux simply ignores the SUID bit on interpreted scripts.

However, the presence of both the SUID bit and world-write permissions on `deploy.sh` remains dangerous. Even though the SUID bit itself has no effect, the script is executed by a root-owned cron job. Since the file is world-writable, any user on the system could modify its contents before the next scheduled execution. When cron runs the script as root, the attacker's code executes with full administrative privileges.

Therefore, the real vulnerability is not the ineffective SUID bit itself, but the combination of an executable script that is writable by everyone and later executed by a privileged process. Removing the SUID bit eliminates confusion, while removing world-write permissions eliminates the actual privilege escalation path.

---

## Question 2: Sudoers Policy Completeness

A policy such as:

```text
amina ALL=(root) NOPASSWD: /usr/bin/systemctl restart *
amina ALL=(root) NOPASSWD: /usr/bin/systemctl status *
```

appears simpler, but it grants permission to restart or inspect every service managed by systemd rather than only the KijaniKiosk services.

One abuse scenario is restarting critical infrastructure services. For example, Amina could restart the SSH daemon, networking services, firewall services, or database services. Restarting these services at the wrong time could interrupt active connections or create a denial-of-service condition for users.

A second abuse scenario is restarting security or monitoring services. An attacker could repeatedly restart monitoring agents, intrusion detection systems, or backup services to interfere with security monitoring or scheduled backups. Although the attacker may not gain direct root access, they could reduce system availability and hide malicious activity.

The restricted policy avoids these risks by allowing `systemctl restart` and `systemctl status` only for `kk-api`, `kk-payments`, and `kk-logs`. This satisfies operational requirements while preventing unintended control over unrelated services.

---

## Question 3: nologin vs Locked Account

### Part A

The two mechanisms serve different purposes.

Using `/usr/sbin/nologin` changes the user's login shell. Authentication may still succeed, but instead of starting an interactive shell, the system immediately terminates the session with a message indicating that the account is unavailable. This is the preferred configuration for service accounts because it prevents interactive logins while still allowing the account to own files and execute background services.

Locking an account with `passwd -l` disables password authentication by placing an invalid marker in the password field. The account still exists and may still be usable through mechanisms that do not rely on password authentication, such as SSH keys or service management tools, depending on system configuration.

A locked account with a normal shell behaves differently from an unlocked account with `/usr/sbin/nologin`. The locked account cannot authenticate using a password, but if authentication occurs through another mechanism, the normal shell still starts. An unlocked account using `/usr/sbin/nologin` can authenticate, but interactive access is immediately denied because the login shell refuses to start.

In production, `/usr/sbin/nologin` is typically used for long-running service accounts that should never be accessed interactively. Locking an account is useful when temporarily disabling a user account without deleting it, such as during employee leave or an incident response investigation.

### Part B

Suppose the deployment pipeline starts the application using:

```bash
sudo -u kk-api /opt/kijanikiosk/scripts/start.sh
```

If the deployment environment or authentication mechanism depends on the account being available and the account has been improperly locked, the startup process may fail because the service account cannot be used as expected.

At runtime, the deployment pipeline would report that the application failed to start. System logs might contain authentication or account-related errors, while the application itself would never begin executing.

A junior engineer might initially suspect that the application has a configuration problem, missing dependencies, incorrect file permissions, or a systemd configuration error. Considerable time could be spent troubleshooting the application before discovering that the service account itself had been locked, preventing the deployment process from successfully running under the intended identity.

This illustrates why service account configuration should be changed carefully and verified after any security hardening.

---

## Question 4: ACLs vs Group Redesign

Both ACLs and groups can be used to share access, but they serve different purposes.

Using ACLs provides fine-grained permissions for individual users or services. In this lab, `kk-api` required write access, while `kk-payments` and `amina` required only read access. ACLs allowed these different permission levels to coexist without changing ownership or creating additional groups.

Using a shared group would simplify the permission model, but every member of the group would generally receive the same permissions. Granting group write permissions would also allow users that only need read access to modify or delete files unless additional controls were implemented.

From a security perspective, ACLs provide stronger isolation because permissions can be tailored for each identity. Shared groups generally provide broader access and therefore increase the impact of a compromised account.

From an audit perspective, ACLs make it easy to determine exactly which identities have been granted additional permissions by using tools such as `getfacl`. Shared groups require administrators to inspect both group memberships and file permissions to understand effective access.

From an operational perspective, groups are simpler to manage when many users require identical permissions. ACLs introduce additional administrative overhead but provide much greater flexibility when different users require different levels of access.

I would choose ACLs whenever multiple identities require different permission levels on the same resource or when following the principle of least privilege is important. I would choose a shared group when a large number of users require identical permissions and the simpler administrative model outweighs the need for fine-grained access control.
