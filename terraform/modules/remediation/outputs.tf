output "sns_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "quarantine_sg_id" {
  description = "ID of the quarantine security group"
  value       = aws_security_group.quarantine.id
}

output "isolate_instance_function_name" {
  description = "Name of the EC2 isolation Lambda function"
  value       = aws_lambda_function.isolate_instance.function_name
}

output "disable_iam_keys_function_name" {
  description = "Name of the IAM key disable Lambda function"
  value       = aws_lambda_function.disable_iam_keys.function_name
}

output "lockdown_s3_function_name" {
  description = "Name of the S3 lockdown Lambda function"
  value       = aws_lambda_function.lockdown_s3.function_name
}