# Centralized Infrastructure Monitoring Architecture

## 1. Executive Summary

The **Centralized Infrastructure Monitoring Platform** is an enterprise-grade observability architecture purpose-built to deliver unified visibility across multi-node AWS infrastructure, EC2 virtual machines, host performance metrics, and containerized/Kubernetes workloads.

Designed strictly around production reliability, cost efficiency, and zero operational bloat, the platform utilizes industry-standard cloud and SRE tooling: **Terraform, AWS VPC/EC2, Prometheus, Node Exporter, Grafana, Alertmanager, Jenkins, and Argo CD**.

---

## 2. End-to-End Architecture Flow

```
+-------------------------------------------------------------------------------------------------+
|                                          AWS VPC (10.0.0.0/16)                                  |
|                                                                                                 |
|   +---------------------------------------+       +-----------------------------------------+   |
|   |   Public Subnet (10.0.1.0/24)         |       |   Private Subnet (10.0.10.0/24)         |   |
|   |                                       |       |                                         |   |
|   |  +---------------------------------+  |       |  +-----------------------------------+  |   |
|   |  | Centralized Monitoring Server   |  |       |  | Monitored EC2 Workload 1          |  |   |
|   |  | (t3.medium)                     |  |       |  | (t3.micro)                        |  |   |
|   |  |                                 |  |       |  |                                   |  |   |
|   |  |  +---------------------------+  |  |       |  |  [Application Service]            |  |   |
|   |  |  | Grafana (Port 3000)       |  |  |       |  |  [Node Exporter :9100] <------+   |  |   |
|   |  |  +-------------+-------------+  |  |       |  +-------------------------------+   |  |   |
|   |  |                |                |  |       |                                      |  |   |
|   |  |                v                |  |       |  +-----------------------------------+| |   |
|   |  |  +---------------------------+  |  |       |  | Monitored EC2 Workload 2          || |   |
|   |  |  | Prometheus (Port 9090)    |--+--+-------+->| [Application Service]            || |   |
|   |  |  +-------------+-------------+  |  | Pull  |  | [Node Exporter :9100] <-------+|| |   |
|   |  |                |                |  | 15s   |  +--------------------------------+|| |   |
|   |  |                v                |  |       |                                    ||   |
|   |  |  +---------------------------+  |  |       +------------------------------------+|   |
|   |  |  | Alertmanager (Port 9093)  |  |  |                                             |   |
|   |  |  +-------------+-------------+  |  |                                             |   |
|   |  |                |                |  |                                             |   |
|   |  +----------------+----------------+  |                                             |   |
|   |                   |                   |                                             |   |
|   +-------------------|-------------------+                                             |   |
|                       | (Webhook/Email)                                                 |   |
|                       v                                                                 |   |
|             [Ops / SRE Team]                                                            |   |
|                                                                                         |   |
|   +---------------------------------------------------------------------------------+   |   |
|   | Optional Kubernetes Cluster / EKS                                               |   |   |
|   |  - Node Exporter DaemonSet (hostPID: true, hostNetwork: true, port 9100)        |   |   |
|   |  - Prometheus Deployment & RBAC (Kubernetes Service Discovery)                 |   |   |
|   |  - Argo CD (GitOps Synchronization from Git Repository)                         |   |   |
|   +---------------------------------------------------------------------------------+   |   |
+-------------------------------------------------------------------------------------------------+
```

---

## 3. Technology Decisions & Trade-Off Analysis

| Component | Selected Technology | Alternative Considered | Why Alternative Was Rejected | Architectural Justification |
| :--- | :--- | :--- | :--- | :--- |
| **IaC** | **Terraform** | CloudFormation, Pulumi | CloudFormation locks into AWS; Pulumi adds programming runtime overhead for simple declarative infrastructure. | Terraform provides declarative state management, module reuse, multi-cloud extensibility, and drift detection. |
| **Host Metrics** | **Node Exporter** | Telegraf, Datadog Agent, CloudWatch Agent | Datadog has vendor cost lock-in; CloudWatch Agent is expensive at high metric frequencies; Telegraf is overly generic. | Official Prometheus host collector; zero memory leak history, low resource footprint (~15MB RAM), standard kernel metrics. |
| **Metric Store** | **Prometheus** | VictoriaMetrics, InfluxDB, Thanos | Thanos/VictoriaMetrics add unnecessary complexity for single-VPC/mid-scale setups. | Native pull model, powerful PromQL engine, dynamic AWS EC2 / Kubernetes service discovery out of the box. |
| **Alerting** | **Alertmanager** | Grafana Alerting, PagerDuty standalone | Grafana alerting couples visual rendering with alert evaluation; PagerDuty has licensing cost. | First-class grouping, deduplication, silencing, and multi-tier routing (critical vs warning) directly downstream of PromQL. |
| **Dashboards** | **Grafana** | Kibana, AWS CloudWatch Dashboards | CloudWatch dashboards have poor PromQL support; Kibana is tied to Elasticsearch/text documents. | The gold standard for multi-tenant, multi-datasource time-series visualization with file-based provisioning. |
| **CI Automation** | **Jenkins** | GitHub Actions, GitLab CI | Mandated by enterprise on-premise governance where build runners reside inside VPC firewall. | Full control over self-hosted build pipelines, pipeline-as-code (`Jenkinsfile`), credential isolation. |
| **CD / GitOps** | **Argo CD** | Flux, Helm CLI via CI | Imperative CLI scripts fail to detect out-of-band cluster drift; Flux lacks granular visual UI for multi-app health. | Git-driven single source of truth, automated drift reconciliation, self-healing k8s manifests. |

---

## 4. Metric Collection Workflow

1. **Scraping Model**: Prometheus operates on a pull-based model. Every 15 seconds, Prometheus sends an HTTP `GET /metrics` request to the targets.
2. **EC2 Dynamic Service Discovery**:
   - Rather than maintaining static IP addresses that break during auto-scaling or re-provisioning, Prometheus queries the AWS EC2 API (`DescribeInstances`) using an IAM instance profile.
   - It filters instances by `tag:ScrapeJob = node-exporter` and extracts private IPs dynamically.
3. **Storage & Retention**:
   - Scraped samples are stored in an append-only Time Series Database (TSDB) on EBS `gp3` storage with a 15-day retention window.
4. **Evaluation**:
   - Every 15 seconds (`evaluation_interval`), recording and alerting rules are evaluated against active time series.

---

## 5. Security & Isolation Architecture

1. **Network Segmentation**:
   - Monitored production servers are deployed exclusively in **Private Subnets** with no public IP addresses.
   - External access is mediated via NAT Gateway for outbound patch management.
2. **Security Groups**:
   - Port `9100` (Node Exporter) is strictly restricted to incoming connections originating from the `monitoring-sg` security group ID.
   - Ports `3000` (Grafana), `9090` (Prometheus), and `9093` (Alertmanager) are never exposed to `0.0.0.0/0`. Ingress is filtered to `admin_allowed_cidr`.
3. **IAM Least-Privilege**:
   - The monitoring instance uses an IAM role with read-only permissions limited to `ec2:DescribeInstances` and `ec2:DescribeTags`.
4. **Zero Hardcoded Secrets**:
   - Passwords and keys are passed via environment variables, Terraform input variables, and Kubernetes Secrets.
