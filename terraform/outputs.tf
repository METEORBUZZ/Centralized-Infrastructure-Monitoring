output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.monitoring_vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "monitoring_server_public_ip" {
  description = "Public IP of the Monitoring Server"
  value       = aws_instance.monitoring_server.public_ip
}

output "monitoring_server_private_ip" {
  description = "Private IP of the Monitoring Server"
  value       = aws_instance.monitoring_server.private_ip
}

output "workload_private_ips" {
  description = "Private IPs of the monitored EC2 workload instances"
  value       = aws_instance.workloads[*].private_ip
}

output "monitoring_security_group_id" {
  description = "ID of the Monitoring Security Group"
  value       = aws_security_group.monitoring_sg.id
}

output "workloads_security_group_id" {
  description = "ID of the Workloads Security Group"
  value       = aws_security_group.workloads_sg.id
}

output "grafana_url" {
  description = "URL to access Grafana Dashboard"
  value       = "http://${aws_instance.monitoring_server.public_ip}:3000"
}

output "prometheus_url" {
  description = "URL to access Prometheus UI"
  value       = "http://${aws_instance.monitoring_server.public_ip}:9090"
}

output "alertmanager_url" {
  description = "URL to access Alertmanager UI"
  value       = "http://${aws_instance.monitoring_server.public_ip}:9093"
}
