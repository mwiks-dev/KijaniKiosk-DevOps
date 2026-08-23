# Service Level Indicators and Objectives for `kk-payments`

## Service Overview

**Service:** `kk-payments` (Payments API behind the Nginx reverse proxy)
**Owner:** Platform Team (Amina)
**SLO Evaluation Period:** Rolling 30-day window

> **Note:** All objectives described below are proposed targets. They have only been validated using a staging traffic simulator and have not yet been verified against real production workloads. After collecting approximately two weeks of production metrics, these targets should be reviewed and adjusted if necessary.

---

# 1. Service Level Indicators (SLIs)

## SLI 1 – Availability

**Definition**

Availability measures the percentage of valid HTTP requests that receive a successful response from the payments service. A successful response is any HTTP status code between **200 and 399**, and measurement is performed at the Nginx proxy.

### Data Source

Availability is calculated using the Nginx access log (`/var/log/nginx/access.log`). The proxy is used as the measurement point because it reflects the customer's experience, including failures caused by unavailable upstream services (such as HTTP 502 or 504), rather than only application-reported errors.

### Calculation

For each 5-minute interval:

> Successful requests (HTTP status < 500) ÷ Total requests

HTTP 4xx responses are treated as successful because the service correctly handled and responded to the client's request, even though the request itself was invalid.

### Measurement

Availability is calculated every five minutes and assessed over a rolling 30-day period.

---

## SLI 2 – Latency

**Definition**

Latency measures the percentage of successful requests that complete within **300 milliseconds**, as observed at the proxy.

### Data Source

The metric is derived from the Nginx `$request_time` field recorded in the access logs. This represents the total request duration experienced by the client, including any upstream connection time.

### Calculation

For each 5-minute interval:

> Successful responses (2xx–3xx) completed in ≤300 ms ÷ Total successful responses (2xx–3xx)

A threshold-based latency indicator is used instead of an average response time because averages can conceal poor tail performance. This approach is also straightforward to calculate directly from log data without requiring a dedicated metrics platform.

### Measurement

Latency is measured in 5-minute buckets and evaluated over a rolling 30-day window.

---

## SLI 3 – Payment Success Rate

**Definition**

This indicator measures the percentage of payment requests that complete successfully without either:

* an HTTP server error (status code 500 or higher), or
* an application-level `payment_failed` event returned within an otherwise successful HTTP response.

### Data Source

This SLI combines two data sources using the request ID:

* Nginx access logs, which provide the HTTP response status.
* Structured application logs written to stdout (currently collected by systemd's journal and planned to be shipped through a production log pipeline).

Although HTTP 200 responses may indicate success at the protocol level, the application logs are required to detect business-level payment failures.

### Calculation

For each 5-minute interval:

> 1 − (Failed payment attempts ÷ Total payment attempts)

### Measurement

The metric is calculated every five minutes and evaluated over a rolling 30-day period.

---

# 2. Service Level Objectives (Rolling 30 Days)

| SLI                  | Target                                               | Approximate 30-Day Error Budget                 |
| -------------------- | ---------------------------------------------------- | ----------------------------------------------- |
| Availability         | 99.9% successful requests                            | Approximately 43 minutes of downtime            |
| Latency              | 99.0% of successful requests completed within 300 ms | Approximately 7.2 hours of degraded performance |
| Payment Success Rate | 99.5% successful payment attempts                    | Roughly 250 failed payments per 50,000 attempts |

These objectives are currently proposed targets rather than production commitments. They have been validated only in a staging environment and should be re-evaluated after sufficient production data has been collected.

The availability objective is intentionally set to **99.9%** instead of **99.99%** because the current architecture relies on a single proxy host without multi-region redundancy. Committing to a higher availability target would therefore be unrealistic.

---

# 3. Automated Rollback Thresholds

While the SLOs represent long-term reliability goals over a 30-day period, automated rollback decisions rely on much shorter observation windows. These thresholds are intentionally less strict than the SLO targets so that routine fluctuations do not trigger unnecessary rollbacks, while genuinely faulty deployments are detected and reversed quickly.

| SLI                  | Rollback Threshold                                                                                                                                   | Relationship to the SLO                                                                                                                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Availability         | Three consecutive failed proxy health checks at 5-second intervals (approximately 15 seconds) within the 90-second post-deployment monitoring window | Fifteen seconds of downtime consumes about 0.6% of the monthly downtime budget. If failures continued at that rate, the entire budget would be exhausted in roughly 29 hours, making immediate rollback the preferable response. |
| Latency              | Three consecutive health checks exceeding the 3-second `curl` timeout (timeouts are treated as failures)                                             | A 3-second response time is ten times higher than the 300 ms latency objective. Sustained performance at this level would quickly jeopardize the monthly latency target.                                                         |
| Payment Success Rate | Five percent or more of payment attempts fail during any 60-second period following deployment (proposed implementation)                             | A 5% failure rate is ten times greater than the permitted monthly failure rate of 0.5%. Maintaining that level for only one hour would consume the entire monthly payment error budget.                                          |

### Current Status

The availability and latency rollback mechanisms have already been implemented and demonstrated using the `post-deploy-monitor.sh` script, achieving an observed recovery time of approximately **12 seconds** from fault detection to rollback.

The payment success-rate rollback mechanism has been designed but is not yet implemented because it depends on the planned log-parsing pipeline.

---

# 4. Exclusions

The following areas are intentionally excluded from these service commitments.

### Third-Party Payment Gateway Availability

Failures caused by external payment providers (such as mobile-money gateways) are not included in the payment success-rate SLO. When an external provider is unavailable, the service is expected to report the error correctly, but such failures are outside our operational control and cannot be resolved through deployment rollback.

### Customer Network Latency

Latency is measured from the Nginx proxy inward. Delays caused by customers' internet or mobile network connections—for example, slow 2G connectivity between a kiosk and our edge infrastructure—are outside the scope of this SLO because they are not actionable by the platform team.

### Batch Reconciliation Jobs

Nightly settlement and reconciliation processes are excluded from the availability and latency objectives described here. These jobs currently have an operational expectation of completing by **06:00**, but no formal SLO has been defined because there is insufficient historical data to establish an appropriate target.
