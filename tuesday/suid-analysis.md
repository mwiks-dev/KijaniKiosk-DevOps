# Why Linux ignores SUID on scripts

Modern Linux kernels ignore the SUID bit on interpreted scripts because of race conditions.

When a script starts, the kernel launches the interpreter (such as Bash), which then opens the script. An attacker could replace the script between these two steps, causing arbitrary commands to execute with elevated privileges.

Ignoring SUID on scripts eliminates this vulnerability.

# Why was this still dangerous?

Although the SUID bit itself has no effect on shell scripts, the file was world writable.

Because a root-owned cron job executes the script, any user could replace its contents with malicious commands.

Cron would later execute those commands as root.

# What makes it exploitable?

A privileged process such as cron, systemd, or another root-owned scheduler executing the writable script makes the vulnerability exploitable.