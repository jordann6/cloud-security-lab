variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for the instance"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to attach"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}