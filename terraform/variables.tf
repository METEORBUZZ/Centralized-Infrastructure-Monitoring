variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. prod, staging, dev)"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated monitoring VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (Bastion / Ingress ALB / Monitoring frontend if needed)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (Workloads, Internal Monitoring backend)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Availability Zones to distribute subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_type_monitoring" {
  description = "EC2 instance type for monitoring host (Prometheus, Grafana, Alertmanager)"
  type        = string
  default     = "t3.medium"
}

variable "instance_type_workload" {
  description = "EC2 instance type for monitored production workload servers"
  type        = string
  default     = "t3.micro"
}

variable "workload_instance_count" {
  description = "Number of monitored workload instances to provision"
  type        = number
  default     = 2
}

variable "admin_allowed_cidr" {
  description = "Admin IP CIDR allowed for SSH and UI management access (restrict to your office/VPN IP)"
  type        = string
  default     = "103.21.124.0/24" # Example secure management subnet; override via terraform.tfvars
}

variable "key_name" {
  description = "Optional pre-existing AWS EC2 Key Pair name"
  type        = string
  default     = ""
}
