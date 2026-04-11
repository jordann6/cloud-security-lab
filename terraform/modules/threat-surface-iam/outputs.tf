output "compromised_user_name" {
  description = "Name of the compromised IAM user"
  value       = aws_iam_user.compromised.name
}

output "compromised_user_arn" {
  description = "ARN of the compromised IAM user"
  value       = aws_iam_user.compromised.arn
}

output "compromised_access_key_id" {
  description = "Access key ID for the compromised user"
  value       = aws_iam_access_key.compromised.id
}

output "compromised_secret_access_key" {
  description = "Secret access key for the compromised user"
  value       = aws_iam_access_key.compromised.secret
  sensitive   = true
}

output "pivot_role_arn" {
  description = "ARN of the pivot role for lateral movement"
  value       = aws_iam_role.pivot.arn
}