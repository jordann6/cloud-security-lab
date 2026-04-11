variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "cloudtrail_log_group_name" {
  description = "CloudWatch Log Group name for CloudTrail logs"
  type        = string
}

variable "cloudtrail_log_group_arn" {
  description = "CloudWatch Log Group ARN for CloudTrail logs"
  type        = string
}

variable "flow_logs_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  type        = string
}

variable "flow_logs_log_group_arn" {
  description = "CloudWatch Log Group ARN for VPC Flow Logs"
  type        = string
}