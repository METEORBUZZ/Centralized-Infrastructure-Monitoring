terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # In production, configure an S3 backend with DynamoDB state locking:
  # backend "s3" {
  #   bucket         = "production-tfstate-monitoring"
  #   key            = "monitoring/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Centralized-Infrastructure-Monitoring"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
