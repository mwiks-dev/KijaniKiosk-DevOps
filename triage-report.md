# KijaniKiosk API Server - Triage Report

**Date:** 2026-07-02
**Investigated by:** Maryann Mwikali
**Server:** mwiks-dev
**Incident start (approximate):** 2024-01-15 04:07 (based on application log evidence)

---

# Summary

The investigation found that the API latency degradation most likely originated from database resource exhaustion rather than CPU or disk exhaustion. Application logs show the database connection pool gradually becoming saturated before being exhausted at approximately **04:07**, followed immediately by query timeouts and later complete database connection failures. Although the server itself is not under critical CPU or disk pressure, a Python process consuming approximately **524 MB** of memory and several unusually large log files contribute additional resource usage that should be addressed.

---

# Process and Resource State

## Memory

System memory status:

* Total RAM: **15 GiB**
* Used: **8.3 GiB**
* Free: **961 MiB**
* Available: **7.0 GiB**
* Swap: **2 GiB configured, 0 B used**

Although free memory is relatively low, over **7 GiB** remains available due to Linux page cache. The system is therefore **not experiencing critical memory pressure**.

## CPU

The system is largely idle:

* CPU Idle: **93.5%**
* Load Average:

  * 1 minute: **0.79**
  * 5 minutes: **0.80**
  * 15 minutes: **0.84**

These values indicate that CPU utilization is not contributing to the latency issue.

## Top Memory Consumers

| Process                | PID   | Memory Usage       |
| ---------------------- | ----- | ------------------ |
| Brave Browser          | 5321  | 5.8% (~949 MB RSS) |
| Brave Renderer         | 18405 | 4.8% (~775 MB RSS) |
| Python Memory Consumer | 60997 | 3.2% (~524 MB RSS) |

The Python process (PID **60997**) corresponds to the workload created during lab setup and represents the primary non-user application consuming memory.

## Highest CPU Consumers

| Process           | PID   | CPU    |
| ----------------- | ----- | ------ |
| Brave Renderer    | 43304 | ~27.5% |
| Brave GPU Process | 5374  | ~15.2% |
| GNOME Shell       | 3264  | ~13.0% |

These are desktop-related processes and are unrelated to the KijaniKiosk application.

## Process Health

* **Zombie processes:** None detected.
* **System state:** No processes observed in an uninterruptible (D) state.
* Open file descriptor counts were highest for Brave browser processes (849, 408, and 191 descriptors respectively), with no indication of file descriptor exhaustion affecting the application.

---

# Filesystem and Disk

## Disk Utilization

| Filesystem | Usage        |
| ---------- | ------------ |
| Root (/)   | **41% used** |

No filesystem exceeded the 80% utilization threshold.

## Largest Log Directories

| Directory            | Size   |
| -------------------- | ------ |
| /var/log/syslog.1    | 1.4 GB |
| /var/log/kern.log.1  | 1.4 GB |
| /var/log/journal     | 506 MB |
| /var/log/kijanikiosk | 271 MB |

The **/var/log/kijanikiosk** directory is considerably larger than expected for a small application because it contains the access log generated during lab setup.

Recent log activity indicates that `syslog`, `kern.log`, and `auth.log` continue to receive updates normally.

Overall, disk utilization is healthy and is **unlikely to be the direct cause of increased API latency**.

---

# Log Analysis

## Error Timeline

Application errors began at approximately:

* **03:45** – Database connection pool reached **85% capacity** (warning)
* **04:01** – Database connection pool reached **94% capacity** (warning)
* **04:07** – Connection pool exhausted
* **04:08** – Query timeout errors began
* **06:22** – Database connections repeatedly refused (`ECONNREFUSED`)
* **06:22** – Retry limit reached and database connection failed

## Error Frequency

| Error Type   | Count |
| ------------ | ----: |
| Query        |     2 |
| Database     |     2 |
| ECONNREFUSED |     2 |
| Connection   |     1 |
| Memory       |     1 |
| Retry        |     1 |

## Observed Pattern

The application logs clearly show a progression rather than isolated failures:

1. Database connection pool usage steadily increased.
2. The pool became exhausted at **04:07**.
3. SQL queries began timing out immediately afterward.
4. Memory usage warnings appeared shortly after the timeouts.
5. Eventually, the application could no longer establish database connections, resulting in repeated `ECONNREFUSED` errors.

No Out-of-Memory (OOM) killer events, disk I/O errors, or authentication anomalies were detected in the system logs.

---

# Network and Service State

## Listening Services

The following services were listening successfully:

* HTTP (Port 80)
* PostgreSQL (Port 5432)
* PostgreSQL (Port 5433)
* MySQL (Port 3306)

## HTTP Connectivity

| Endpoint                    | Result                    |
| --------------------------- | ------------------------- |
| http://localhost/           | HTTP **200** (0.002757 s) |
| http://localhost/api/health | HTTP **404** (0.000601 s) |

The web server is operational and responds quickly.

The `/api/health` endpoint returned **404**, indicating that the endpoint is unavailable or not configured.

## TCP Connection Summary

* Established connections: **14**
* Listening sockets: **12**
* TIME_WAIT connections: **2**

No abnormal TCP connection buildup was observed.

---

# Assessment

The most probable cause of the API latency increase is **database resource exhaustion**.

The application logs demonstrate a clear sequence in which database connection pool utilization increased until the pool became exhausted at approximately **04:07**, causing SQL query timeouts. As requests accumulated while waiting for database connections, memory usage also increased, eventually leading to repeated `ECONNREFUSED` errors when the database became unavailable.

CPU utilization remained low, memory remained available, and disk utilization stayed well below critical thresholds, indicating that these system resources were not the primary cause of the degradation. The oversized log files and Python memory consumer contribute additional resource usage but are secondary findings rather than the root cause.

---

# Recommended Next Steps

1. Investigate the database server and connection pool configuration to determine why connections became exhausted, and optimize pool sizing or query performance.
2. Review and terminate unnecessary high-memory processes (such as the Python memory consumer after confirming it is not production-critical) and continue monitoring overall memory usage.
3. Implement or verify log rotation and archival for large log files within `/var/log/kijanikiosk` and other system logs to prevent unnecessary disk growth over time.
