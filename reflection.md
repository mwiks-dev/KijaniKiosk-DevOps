# Week 3 Monday Reflection

## 1. The /proc Boundary

The `/proc` filesystem is a virtual filesystem created and maintained by the Linux kernel. Unlike a normal filesystem, the files and directories inside `/proc` are not stored on disk. Instead, they are generated dynamically in memory whenever they are accessed. The kernel exposes information about running processes, hardware, memory, CPU usage, and other system resources through this interface.

Because `/proc` exists only while the operating system is running, its contents do not persist after a reboot. When the system restarts, every process receives a new process ID (PID), memory allocations change, and the kernel recreates the `/proc` filesystem from scratch. This means that the information viewed during the investigation represented a real-time snapshot of the current state of the system rather than permanent records.

During the investigation, commands such as `ps`, `top`, and `cat /proc/meminfo` were all reading live kernel data through `/proc`. The process list, memory statistics, and open file descriptors reflected the system's current state at that exact moment.

---

## 2. Kernel Space and Process Isolation

The memory-consuming Python process created during the lab was running in user space. User-space processes execute with limited privileges and cannot directly access kernel memory. This protection is enforced by the processor's hardware memory protection mechanisms, specifically virtual memory and privilege levels (user mode and kernel mode).

Each process operates within its own virtual address space managed by the Memory Management Unit (MMU). If a user-space process attempts to access memory outside its allocated space, the processor generates a segmentation fault or other protection exception instead of allowing access.

If this boundary did not exist, any faulty or malicious application could overwrite kernel memory, corrupt operating system structures, crash the entire machine, or gain complete control of the system. The separation between user space and kernel space is therefore one of the fundamental security and stability features of modern operating systems.

---

## 3. The Triage Pipeline I Built

One of the more complex commands used during the investigation was:

```bash
grep -E "ERROR|WARN|CRITICAL" /var/log/kijanikiosk/app.log | \
awk '{print $4}' | sort | uniq -c | sort -rn
```

Each stage performs a specific task:

1. `grep -E "ERROR|WARN|CRITICAL"` filters the application log and outputs only lines containing warning or error messages.

2. `awk '{print $4}'` extracts the fourth field from each matching line, which corresponds to the primary error category (for example, `Database`, `Query`, or `ECONNREFUSED`).

3. `sort` arranges the extracted values alphabetically so that identical entries appear next to one another.

4. `uniq -c` counts consecutive duplicate entries. Since `uniq` only counts adjacent duplicates, the previous `sort` command is necessary.

5. `sort -rn` sorts the counts numerically in descending order, displaying the most frequent error types first.

If the order of `sort` and `uniq -c` were reversed, identical entries would not necessarily be adjacent, causing `uniq` to produce incorrect counts. This demonstrates that the order of commands in a Unix pipeline is important because each command depends on the output produced by the previous one.

---

## 4. Containers and the Kernel

If the KijaniKiosk application had been running inside a Docker container, its processes would still have appeared in the host's `ps aux` output because containers do not run their own kernel. Instead, they share the host's Linux kernel.

The host operating system schedules every process running on the machine, including processes inside containers. As a result, the host can always view and manage container processes.

Container isolation is provided through Linux namespaces and control groups (cgroups). Namespaces isolate resources such as process IDs, networking, mount points, users, and hostnames so that processes inside a container have their own limited view of the system. Cgroups enforce limits on CPU, memory, and other resources consumed by containerized applications.

Containers therefore provide process and resource isolation rather than complete operating system virtualization. Unlike virtual machines, they do not include a separate kernel.

---

## 5. Operational Consequence

The simulated Python memory-consuming process was not the primary cause of the API latency. Instead, it was an additional workload running on the system while the real failure originated elsewhere.

The application logs show a clear failure cascade. At approximately **03:45**, the database connection pool reached **85%** capacity, indicating increasing pressure on database resources. By **04:01**, the pool had grown to **94%**, leaving very few available connections. At **04:07**, the connection pool became completely exhausted, preventing new database requests from acquiring connections.

Once the connection pool was exhausted, application requests began waiting for available database connections. This caused SQL queries to time out at approximately **04:08**, increasing API response times significantly. As requests accumulated while waiting, the application logged elevated memory usage because pending requests remained in memory longer than normal.

Eventually, at **06:22**, the application could no longer establish any database connections and repeatedly logged `ECONNREFUSED` errors before reaching the retry limit.

The overall failure sequence was:

**Increasing database load → connection pool exhaustion → query timeouts → request backlog and increased memory usage → database connection failures (`ECONNREFUSED`) → degraded API performance.**

This investigation demonstrates that symptoms such as increased memory usage may be secondary effects, while the true root cause lies earlier in the chain of events. Effective incident response requires correlating resource usage with application logs to distinguish root causes from downstream symptoms.
