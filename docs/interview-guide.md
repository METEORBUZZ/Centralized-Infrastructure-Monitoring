# Senior DevOps / SRE Interview Discussion Guide

This guide prepares engineers to speak authoritatively about the architectural decisions, trade-offs, security postures, and incident lifecycle mechanisms implemented in this project during senior technical interviews.

---

### Q1: Why did you choose Prometheus over push-based solutions like CloudWatch Agent or Datadog?
**Answer**:
- **Pull vs Push Control**: Prometheus pulls metrics over HTTP. This means the monitoring server dictates the scrape frequency and network volume. If Prometheus becomes overloaded, it doesn't crash from backpressure; it simply stretches scrape intervals. With push agents, a fleet of thousands of nodes pushing simultaneously can flood ingestion endpoints (thundering herd problem).
- **Service Discovery**: Prometheus natively integrates with the AWS EC2 API. Workload instances do not need static IP configurations or service endpoints hardcoded; they simply tag instances, and Prometheus queries AWS using IAM instance profiles.
- **Cost**: Datadog pricing per host ($15-$23/host/mo) plus custom metric ingestion costs escalate exponentially. Prometheus is open source, lightweight, and self-hosted on EBS `gp3`.

---

### Q2: Why Node Exporter instead of writing custom monitoring scripts?
**Answer**:
- Node Exporter is the CNCF/Prometheus standard for exposing Linux host and kernel metrics.
- Written in Go, it has zero external dependencies, negligible CPU overhead (< 0.5%), and minimal memory consumption (< 15MB).
- It reads directly from the Linux `/proc` and `/sys` virtual filesystems, gathering accurate kernel stats (context switches, disk I/O wait, memory buffers/cache, network socket states) without spawning shell processes.

---

### Q3: How does dynamic AWS EC2 discovery work in Prometheus?
**Answer**:
- In `prometheus.yml`, we configure an `ec2_sd_configs` block specifying the region and tag filters (`tag:ScrapeJob = node-exporter`).
- Prometheus leverages the AWS EC2 instance profile (`aws_iam_instance_profile`) attached to its EC2 host, which possesses `ec2:DescribeInstances` read-only privileges.
- Using `relabel_configs`, Prometheus converts the dynamic AWS metadata label `__meta_ec2_private_ip` into `__address__` (port 9100) and extracts `__meta_ec2_tag_Name` into an `instance` label. When auto-scaling groups launch new EC2 instances, Prometheus discovers and begins scraping them within 60 seconds without manual intervention or configuration restarts.

---

### Q4: Why Alertmanager instead of sending alerts directly from Prometheus or Grafana?
**Answer**:
- **Separation of Concerns**: Prometheus evaluates alert conditions using PromQL. Alertmanager handles alert deduplication, grouping, inhibition, and routing.
- **Inhibition**: If a hypervisor or EC2 instance dies, the `HostDown` alert fires. Without Alertmanager inhibition, the operations team would simultaneously receive alerts for High CPU, High Memory, Service Down, and Port Unreachable on the same dead instance. With Alertmanager's `inhibit_rules`, the critical `HostDown` alert suppresses all child warning alerts for that instance.
- **Grouping**: When a network switch hiccups, 50 nodes might fail simultaneously. Alertmanager groups them into a single notification batch rather than sending 50 individual pages.

---

### Q5: Why did you select Jenkins instead of GitHub Actions?
**Answer**:
- In many regulated enterprise, banking, and government environments, security compliance prohibits passing private VPC network credentials or SSH keys to third-party SaaS runners like GitHub Actions.
- Jenkins operates on a private EC2/Kubernetes runner inside our VPC. It has native access to private subnets without opening external inbound webhook firewall ports.
- The pipeline is defined strictly as code via a declarative `Jenkinsfile`, keeping build definitions versioned and auditable in Git.

---

### Q6: Why Argo CD instead of deploying directly from the CI pipeline?
**Answer**:
- **GitOps Pull Model vs Push Model**: Traditional CI deployment pushes changes into the cluster via `kubectl apply`. This requires storing high-privilege cluster admin credentials inside CI runners. If CI is compromised, the cluster is compromised.
- Argo CD runs *inside* the Kubernetes cluster, pulling manifests from the Git repository. No inbound cluster credentials ever leave the VPC.
- **Drift Detection & Self-Healing**: If an engineer manually edits or deletes a Kubernetes deployment via `kubectl edit`, Argo CD detects the divergence from Git within minutes and automatically reconciles the cluster state back to the Git source of truth (`selfHeal: true`).

---

### Q7: How is the monitoring platform secured against unauthorized access?
**Answer**:
1. **Network Layer**: Workload instances reside in private subnets. Node Exporter port `9100` only accepts traffic originating from the security group of the monitoring server (`monitoring-sg`).
2. **Management Access**: Port `3000` (Grafana), `9090` (Prometheus), and `9093` (Alertmanager) are filtered to trusted administrative IP blocks (`admin_allowed_cidr`) rather than open to the internet.
3. **IAM Least-Privilege**: Prometheus is restricted to read-only `DescribeInstances` and `DescribeTags` API actions.
4. **Container Security**: The Kubernetes manifests execute all monitoring daemons as non-root users (`runAsUser: 65534`, `runAsUser: 472`), drop default Linux capabilities, and mount root filesystems as read-only.
5. **Zero Secrets in Code**: Scanned automatically by pre-commit hooks and Jenkins CI pipelines.

---

### Q8: What happens if Prometheus goes down? How do you monitor the monitor?
**Answer**:
- **Dead Man's Snitch / Watchdog Alert**: Prometheus continuously sends a heartbeat alert named `Watchdog` to Alertmanager, which forwards it to an external service (e.g. Healthchecks.io / DeadMansSnitch). If the heartbeat stops, the external service alerts the SRE team that the monitoring pipeline is silent.
- **AWS CloudWatch Alarms**: A basic, low-cost AWS CloudWatch alarm monitors the Prometheus EC2 instance status checks (`StatusCheckFailed_System` / `StatusCheckFailed_Instance`).
- **Kubernetes Self-Healing**: In a Kubernetes deployment, liveness and readiness probes (`/-/healthy`, `/-/ready`) automatically restart unhealthy Prometheus pods.

---

### Q9: How would you scale this architecture if the fleet grew to 5,000 servers?
**Answer**:
1. **Target Sharding**: Split scrape targets across multiple Prometheus instances using hash-based sharding (consistent hashing on target addresses).
2. **Prometheus Agent Mode**: Run Prometheus in `agent` mode (which scrapes and discards TSDB storage, immediately streaming samples via `remote_write`).
3. **Central Long-Term Storage**: Stream metrics to a scalable distributed store like VictoriaMetrics cluster or Thanos with object storage backends (AWS S3) for compaction, deduplication, and multi-year queries.
4. **Recording Rules**: Precompute expensive PromQL aggregation queries into lightweight time series to preserve dashboard render speed.

---

### Q10: How do you reduce monitoring noise and alert fatigue?
**Answer**:
1. **Duration Windows (`for: 5m`)**: Never alert immediately on momentary threshold spikes; allow a cooldown window to confirm persistence.
2. **Predictive Rate of Change**: Use PromQL functions like `predict_linear()` to detect storage exhaustion hours in advance rather than waiting for an emergency 95% full state.
3. **Symptom-Based Alerting**: Focus alerts on customer-impacting symptoms (latency, error rate, saturation) rather than every trivial warning.
4. **Inhibition Rules**: Suppress downstream alerts when a master root-cause alert is already firing.
