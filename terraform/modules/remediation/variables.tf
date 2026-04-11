variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "notification_email" {
  description = "Email address for SNS alert notifications"
  type        = string
}

variable "threat_instance_id" {
  description = "EC2 instance ID to target for automated isolation"
  type        = string
}

variable "permissive_sg_id" {
  description = "Permissive security group ID to revoke"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for creating quarantine security group"
  type        = string
}