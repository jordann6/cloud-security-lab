output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "permissive_sg_id" {
  description = "ID of the permissive security group"
  value       = aws_security_group.permissive.id
}

output "flow_logs_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "flow_logs_log_group_arn" {
  description = "CloudWatch Log Group ARN for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.arn
}