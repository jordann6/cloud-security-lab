variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the threat surface S3 bucket for CloudTrail data events"
  type        = string
}