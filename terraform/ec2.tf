# Lookup latest official Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Optional generated SSH key pair if key_name is not provided
resource "tls_private_key" "monitoring_key" {
  count     = var.key_name == "" ? 1 : 0
  algorithm = "ED25519"
}

resource "aws_key_pair" "generated_key" {
  count      = var.key_name == "" ? 1 : 0
  key_name   = "${var.environment}-monitoring-key"
  public_key = tls_private_key.monitoring_key[0].public_key_openssh
}

locals {
  ssh_key_name = var.key_name != "" ? var.key_name : aws_key_pair.generated_key[0].key_name
}

# 1. Monitored Workload EC2 Instances (Placed in Private Subnets)
resource "aws_instance" "workloads" {
  count                  = var.workload_instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_workload
  subnet_id              = aws_subnet.private[count.index % length(aws_subnet.private)].id
  vpc_security_group_ids = [aws_security_group.workloads_sg.id]
  key_name               = local.ssh_key_name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Production user_data installs and enables systemd node_exporter
  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update -y
              apt-get install -y wget curl daemonize prometheus-node-exporter

              systemctl enable prometheus-node-exporter
              systemctl start prometheus-node-exporter
              EOF

  tags = {
    Name        = "${var.environment}-workload-${count.index + 1}"
    Role        = "workload"
    ScrapeJob   = "node-exporter"
    Environment = var.environment
  }
}

# 2. Centralized Monitoring Server (Prometheus + Grafana + Alertmanager)
# Placed in Public Subnet for admin accessibility (or Bastion), with strict SG rules
resource "aws_instance" "monitoring_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_monitoring
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.prometheus_profile.name
  key_name               = local.ssh_key_name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release git docker.io docker-compose
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name        = "${var.environment}-monitoring-server"
    Role        = "monitoring"
    Environment = var.environment
  }
}
