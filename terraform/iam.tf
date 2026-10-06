# IAM Role for Prometheus EC2 instance to support AWS EC2 Service Discovery
resource "aws_iam_role" "prometheus_discovery_role" {
  name = "${var.environment}-prometheus-discovery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment}-prometheus-discovery-role"
  }
}

# Least privilege IAM Policy allowing Prometheus to query EC2 metadata
resource "aws_iam_policy" "prometheus_ec2_sd_policy" {
  name        = "${var.environment}-prometheus-ec2-sd-policy"
  description = "Allows Prometheus to discover EC2 instances dynamically based on tags"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_sd_attach" {
  role       = aws_iam_role.prometheus_discovery_role.name
  policy_arn = aws_iam_policy.prometheus_ec2_sd_policy.arn
}

resource "aws_iam_instance_profile" "prometheus_profile" {
  name = "${var.environment}-prometheus-instance-profile"
  role = aws_iam_role.prometheus_discovery_role.name
}
