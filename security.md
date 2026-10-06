# Security Architecture & Hardening Guide

## 1. Security Philosophy
Security in this platform is built using **Defense in Depth**:
- Network security (Private VPC, security group source references)
- Identity & Access Management (Least-privilege IAM roles, no root keys)
- Service level isolation (Non-root Linux daemons, restricted Docker mounts)
- Static code & secret scanning in CI/CD pipeline

---

## 2. Network Security & Ingress Control

### 2.1 Security Group Matrix

| Security Group | Inbound Port | Protocol | Allowed Source | Justification |
| :--- | :--- | :--- | :--- | :--- |
| **`monitoring-sg`** | `22` | TCP | `admin_allowed_cidr` | Secure administrative shell access |
| **`monitoring-sg`** | `3000` | TCP | `admin_allowed_cidr` | Grafana visual dashboard portal |
| **`monitoring-sg`** | `9090` | TCP | `admin_allowed_cidr` | Prometheus administrative interface |
| **`monitoring-sg`** | `9093` | TCP | `admin_allowed_cidr` | Alertmanager administrative interface |
| **`workloads-sg`** | `9100` | TCP | `monitoring-sg` (ID) | Node Exporter scrape (Prometheus server ONLY) |
| **`workloads-sg`** | `80` | TCP | `10.0.0.0/16` (VPC CIDR) | Monitored internal application services |
| **`workloads-sg`** | `22` | TCP | `admin_allowed_cidr` | Administrative debugging |

### 2.2 Why Node Exporter is Never Exposed Publicly
Node Exporter metrics expose detailed internal operating system information:
- Exact kernel versions, CPU architecture, process IDs
- Filesystem mount points and storage capacities
- Network interface topologies and packet counters

Leaving port `9100` exposed to `0.0.0.0/0` invites reconnaissance and denial-of-service scraping attacks. In this architecture, it is only reachable by the monitoring instance's Security Group.

---

## 3. IAM Least-Privilege Policy

Prometheus dynamically queries EC2 metadata. Instead of using administrator credentials or static API keys, an EC2 Instance Profile is attached with the following restrictive policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
```

Prometheus cannot create, modify, stop, or delete any AWS resources.

---

## 4. Kubernetes Security Controls

1. **Non-Root Execution**:
   - Prometheus runs as user `65534:65534` (`nobody`).
   - Grafana runs as user `472:472` (`grafana`).
2. **Read-Only Root Filesystem**:
   - Exporter containers run with `readOnlyRootFilesystem: true`.
3. **Restricted RBAC**:
   - The Prometheus ClusterRole is restricted to `get`, `list`, and `watch` on endpoints, nodes, and pods. It cannot read Secret objects or perform mutations.
4. **Namespaced Isolation**:
   - All monitoring workloads reside in the dedicated `monitoring` namespace.

---

## 5. Security Testing Matrix

| Threat Vector | Attack Scenario | Implemented Defense | Validation Command | Result |
| :--- | :--- | :--- | :--- | :--- |
| **Public Exporter Access** | Unauthorized scrape of port 9100 from Internet | Workload instances placed in private subnet with SG filtering | `curl -m 3 http://<workload-ip>:9100/metrics` | Connection timed out / Blocked |
| **Credential Leakage** | Committing AWS keys or private keys to Git | Automated regex scanning in Jenkins CI & pre-commit script | `bash scripts/tests/security-scan.sh` | Clean (0 secrets found) |
| **Privilege Escalation** | Compromised Prometheus container modifying AWS | IAM policy restricted strictly to `ec2:Describe*` | Attempting `aws ec2 terminate-instances` fails with AccessDenied | Denied |
| **Grafana Brute-Force** | Open registration or default credentials | `GF_USERS_ALLOW_SIGN_UP=false`, admin password passed securely via secrets | Accessing `/signup` endpoint returns 404/disabled | Protected |
