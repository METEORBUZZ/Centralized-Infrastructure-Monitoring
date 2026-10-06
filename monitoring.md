# Monitoring & Alerting Strategy Guide

## 1. Metrics Collected & PromQL Queries

The platform monitors critical host and workload health vectors using standard Node Exporter metrics:

### 1.1 CPU Utilization
- **Metric**: `node_cpu_seconds_total`
- **Calculation Formula**:
  ```promql
  100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
  ```
- **Operational Purpose**: Measures percentage of CPU time spent in active computation across user, system, and iowait modes.

### 1.2 Memory Utilization
- **Metrics**: `node_memory_MemAvailable_bytes`, `node_memory_MemTotal_bytes`
- **Calculation Formula**:
  ```promql
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
  ```
- **Operational Purpose**: Evaluates real available memory (accounting for page cache and buffer reclaimability) to predict OOM killer risks.

### 1.3 Disk Usage & Predictive Exhaustion
- **Metrics**: `node_filesystem_free_bytes`, `node_filesystem_size_bytes`
- **Current Utilization Formula**:
  ```promql
  (1 - (node_filesystem_free_bytes{fstype=~"ext4|xfs",mountpoint="/"} / node_filesystem_size_bytes{fstype=~"ext4|xfs",mountpoint="/"})) * 100
  ```
- **Linear Trend Prediction Formula (Predict fill within 4 hours)**:
  ```promql
  predict_linear(node_filesystem_free_bytes{fstype=~"ext4|xfs",mountpoint="/"}[1h], 4 * 3600) < 0
  ```

### 1.4 Network Traffic & Interface Health
- **Metrics**: `node_network_receive_bytes_total`, `node_network_transmit_bytes_total`, `node_network_receive_errs_total`
- **Throughput Calculation**:
  ```promql
  rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*"}[2m])
  ```

### 1.5 Host Availability (Heartbeat)
- **Metric**: `up`
- **Calculation Formula**:
  ```promql
  up{job=~"node-exporter.*|aws-ec2-nodes"} == 0
  ```

---

## 2. Production Alert Rules Matrix

Every alert in the platform is justified by operational necessity and designed to minimize alert fatigue.

| Alert Name | Severity | Evaluation Interval | Threshold & Condition | Operational Rationale | Runbook Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`HostDown`** | `critical` | 2 minutes | `up == 0` for 2m | Node Exporter scrape failed or server crashed; workloads on instance are offline. | Check EC2 instance state via AWS CLI / console, inspect hypervisor health, check systemd service. |
| **`HostHighCpuLoad`** | `warning` | 5 minutes | CPU > 85% for 5m | Sustained high compute will cause latency degradation and queuing. 5-minute window prevents temporary spikes from paging on-call. | Inspect `top` / `htop` for runaway processes; scale vertically or horizontally. |
| **`HostHighMemoryUsage`** | `warning` | 5 minutes | Memory > 90% for 5m | Approaching OOM killer threshold. Immediate risk of kernel killing application processes. | Review memory leak profiles, inspect resident memory set per process, restart leaking service. |
| **`HostDiskSpaceFillingUp`** | `warning` | 5 minutes | Disk > 85% for 5m | Risk of write lockups, database corruption, or application failure due to full root partition. | Purge rotated log files in `/var/log`, clean docker prune cache, expand EBS volume. |
| **`HostDiskPredictWillFillIn4Hours`** | `critical` | 10 minutes | Linear consumption rate projects 0 bytes in 4 hours | Catches rapid disk consumption (e.g. rogue debug logging) long before it hits 85%. | Identify writing process with `lsof +L1` and `iotop`, stop log flood, expand volume. |
| **`HostNetworkReceiveErrors`** | `warning` | 2 minutes | Packet errors > 10/s | Network interface hardware or driver drops; TCP retransmission and packet loss. | Inspect MTU settings, AWS Elastic Network Adapter (ENA) driver status, cable/switch if physical. |

---

## 3. Alertmanager Deduplication & Inhibition Architecture

Alert storms during major infrastructure outages are prevented via Alertmanager grouping and inhibition:

1. **Grouping**:
   - Alerts with matching `alertname`, `service`, and `tier` are grouped into a single notification (`group_wait: 30s`).
2. **Inhibition**:
   - If an instance triggers `HostDown` (`severity: critical`), all downstream `severity: warning` alerts (e.g. CPU, memory, disk) for that same instance are automatically **inhibited** (suppressed).
   - This prevents on-call engineers from receiving 5 separate alerts for a server that simply stopped running.
3. **Repeat Intervals**:
   - Critical alerts repeat every 1 hour if unresolved.
   - Warnings repeat every 6 hours to prevent spam while tracking persistent issues.
