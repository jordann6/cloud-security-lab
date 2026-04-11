variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "project_name" {
  description = "Project name used for tagging and naming"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "notification_email" {
  description = "Email address for security alert notifications"
  type        = string
}

variable "my_ip" {
  description = "Public IP address allowed to access OpenSearch Dashboards"
  type        = string
}