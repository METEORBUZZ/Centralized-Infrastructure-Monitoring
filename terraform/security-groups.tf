# 1. Security Group for Monitored Workloads (EC2 Instances)
resource "aws_security_group" "workloads_sg" {
  name        = "${var.environment}-workloads-sg"
  description = "Security group for monitored production EC2 instances"
  vpc_id      = aws_vpc.monitoring_vpc.id

  # Inbound Node Exporter metrics (Port 9100) strictly from Monitoring Security Group
  ingress {
    description     = "Allow Prometheus scraping on Node Exporter port"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }

  # Inbound Application Traffic (e.g. HTTP Port 80)
  ingress {
    description = "Allow HTTP internal application traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH strictly from authorized administrator CIDR / Bastion
  ingress {
    description = "Admin SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_allowed_cidr]
  }

  # Outbound egress to internet via NAT (for apt updates / package mirrors)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-workloads-sg"
  }
}

# 2. Security Group for Monitoring Host (Prometheus, Grafana, Alertmanager)
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.environment}-monitoring-sg"
  description = "Security group for centralized monitoring servers"
  vpc_id      = aws_vpc.monitoring_vpc.id

  # Grafana Web Dashboard (Port 3000) restricted to admin CIDR
  ingress {
    description = "Grafana dashboard access restricted to Admin CIDR"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.admin_allowed_cidr]
  }

  # Prometheus Web Interface (Port 9090) restricted to admin CIDR
  ingress {
    description = "Prometheus web UI restricted to Admin CIDR"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.admin_allowed_cidr]
  }

  # Alertmanager Web Interface (Port 9093) restricted to admin CIDR
  ingress {
    description = "Alertmanager web UI restricted to Admin CIDR"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [var.admin_allowed_cidr]
  }

  # In-host Node Exporter scrape (local host monitoring)
  ingress {
    description = "Self-scrape node exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    self        = true
  }

  # Admin SSH access
  ingress {
    description = "Admin SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_allowed_cidr]
  }

  # Outbound egress (scraping targets in VPC, sending webhooks/emails, fetching images)
  egress {
    description = "Allow outbound scraping and external alert delivery"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-monitoring-sg"
  }
}
