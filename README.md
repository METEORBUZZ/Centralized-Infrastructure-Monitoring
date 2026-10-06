# Centralized Infrastructure Monitoring

A production-grade, cost-conscious infrastructure observability platform providing centralized visibility into AWS infrastructure, virtual machines, resource saturation, host availability, and operational alerting.

Built strictly according to real-world DevOps/SRE standards using **Terraform, AWS VPC/EC2, Prometheus, Node Exporter, Grafana, Alertmanager, Jenkins, and Argo CD**.

---

## Architecture Overview

```
AWS Infrastructure (VPC & EC2)
              |
              v
        Node Exporter (:9100)
              |
              v (HTTP Pull / Dynamic EC2 Discovery)
         Prometheus (:9090)
              |
       +------+------+
       |             |
       v             v
 Grafana (:3000) Alertmanager (:9093)
       |             |
  Dashboards     Alert Webhooks / Pager
```

### Key Technical Characteristics
- **Dynamic Cloud Discovery**: Prometheus automatically discovers monitored EC2 workloads using AWS EC2 tags (`ScrapeJob=node-exporter`) and IAM instance profiles. No static hostnames to maintain.
- **Defense-in-Depth Security**: Monitored production servers reside in **Private Subnets** with outbound-only NAT connectivity. Node Exporter port `9100` is strictly restricted to Prometheus server Security Group.
- **Actionable Alerting**: Thresholds with duration windows (`for: 5m`) eliminate transient spikes. Includes predictive disk exhaustion (`predict_linear`) and alert inhibition rules.
- **GitOps & CI Automation**: Declarative Jenkins CI pipeline for linting, Terraform validation, and automated secret scanning; Argo CD application manifests for Kubernetes-native synchronization.

---

## Repository Structure

```
centralized-infrastructure-monitoring/
│
├── terraform/                       # Infrastructure as Code (AWS VPC, Subnets, SG, IAM, EC2)
│   ├── providers.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── subnet.tf
│   ├── security-groups.tf
│   ├── iam.tf
│   ├── ec2.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── monitoring/                      # Monitoring configurations
│   ├── prometheus/
│   │   ├── prometheus.yml           # Scrape jobs & AWS EC2 discovery config
│   │   └── alert.rules.yml          # Production PromQL alert rules
│   ├── alertmanager/
│   │   └── alertmanager.yml         # Routing trees, inhibition & receivers
│   ├── grafana/
│   │   ├── provisioning/            # Datasource & dashboard file providers
│   │   └── dashboards/
│   │       └── infrastructure-overview.json # Production Grafana dashboard
│   └── node-exporter/
│       ├── node_exporter.service    # Systemd service unit definition
│       └── install-node-exporter.sh # Multi-architecture Linux installer
│
├── kubernetes/                      # Kubernetes-native manifests
│   ├── namespaces/
│   ├── exporters/                   # Node Exporter DaemonSet
│   ├── prometheus/                  # Prometheus Deployment, RBAC, ConfigMap
│   ├── grafana/                     # Grafana Deployment & Secrets
│   └── alertmanager/                # Alertmanager Deployment
│
├── argocd/                          # GitOps manifests
│   └── applications/
│       └── monitoring-stack-application.yaml
│
├── jenkins/                         # CI Pipeline
│   └── Jenkinsfile                  # Linting, Terraform validation, secret scan
│
├── docker/                          # Local containerized deployment
│   └── docker-compose.yml           # Full standalone monitoring stack
│
├── scripts/                         # Operational & Testing automation
│   ├── chaos/chaos-test.sh          # Chaos & failure simulation script
│   └── tests/security-scan.sh       # Secret and credential audit script
│
├── docs/interview-guide.md          # 15+ Senior SRE interview questions & deep dives
├── architecture.md                  # Comprehensive architectural design & decisions
├── security.md                      # Network boundaries, IAM & hardening guide
├── monitoring.md                    # Metrics, PromQL queries & alert rationale
├── testing.md                       # Realistic failure tests & verification log
└── .gitignore
```

---

## Getting Started

### 1. Local Testing via Docker Compose
To test the complete monitoring stack locally with simulated workload nodes:

```bash
# Verify Compose configuration
docker compose -f docker/docker-compose.yml config

# Start the stack
docker compose -f docker/docker-compose.yml up -d

# Access endpoints:
# Grafana:       http://localhost:3000 (admin / admin)
# Prometheus:    http://localhost:9090
# Alertmanager:  http://localhost:9093
# Node Exporter: http://localhost:9100
```

### 2. AWS Provisioning with Terraform

```bash
cd terraform

# 1. Copy sample variables and edit with your admin CIDR
cp terraform.tfvars.example terraform.tfvars
# nano terraform.tfvars

# 2. Initialize and validate Terraform
terraform init
terraform validate

# 3. Plan and apply
terraform plan -out=tfplan
terraform apply tfplan

# Outputs will display public and private IPs, Security Group IDs, and Web URLs.
```

### 3. Kubernetes / Argo CD Deployment

```bash
# Apply monitoring namespace
kubectl apply -f kubernetes/namespaces/monitoring-namespace.yaml

# Create Grafana admin secret
kubectl -n monitoring create secret generic grafana-admin-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='ChangeMeInProduction123!'

# Deploy via Argo CD
kubectl apply -f argocd/applications/monitoring-stack-application.yaml
```

---

## Failure & Chaos Testing

Test alert triggers and recovery using the provided script:

```bash
# 1. Test CPU Saturation Alert
./scripts/chaos/chaos-test.sh cpu-stress

# 2. Test Disk Exhaustion Alert
./scripts/chaos/chaos-test.sh disk-stress
./scripts/chaos/chaos-test.sh cleanup-disk

# 3. Test Host Downtime Alert
./scripts/chaos/chaos-test.sh stop-exporter
./scripts/chaos/chaos-test.sh restore-exporter
```

---

## AWS Cost Breakdown & Optimization

| AWS Resource | Size / Spec | Estimated Cost | Cost Optimization Strategy |
| :--- | :--- | :--- | :--- |
| **Monitoring Host** | 1x `t3.medium` (2 vCPU, 4GB RAM) | ~$30.37/mo | Free tier eligible for initial testing on `t3.micro`/`t4g.small`. Scale to medium for production TSDB. |
| **Workload Instances** | 2x `t3.micro` (1 vCPU, 1GB RAM) | Free Tier / ~$15.18/mo | Uses AWS Free Tier (750 hours/mo). Node Exporter uses < 15MB RAM. |
| **EBS Storage** | 30GB `gp3` (Monitoring) + 2x 20GB `gp3` | ~$5.60/mo | `gp3` offers 20% lower baseline price than `gp2`. 15-day retention caps metric volume under 10GB. |
| **NAT Gateway** | 1x NAT Gateway + Data transfer | ~$32.40/mo | Single NAT Gateway shared across private subnets. For strict dev budgets, use a NAT instance or VPC endpoints. |

---

## Documentation Links

- [Architecture Design & Tool Decisions](architecture.md)
- [Security Hardening & IAM Architecture](security.md)
- [Prometheus PromQL & Alerting Matrix](monitoring.md)
- [Testing & Failure Scenarios Report](testing.md)
- [Senior DevOps / SRE Interview Guide](docs/interview-guide.md)
