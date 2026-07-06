# Root outputs. The compromised credentials are consumed by the attack/ kill-chain
# scripts; everything staged here is intentionally vulnerable lab material.

output "compromised_user_name" {
  description = "Name of the intentionally compromised IAM user"
  value       = module.threat_surface_iam.compromised_user_name
}

output "compromised_access_key_id" {
  description = "Leaked access key ID used to seed the kill-chain simulation"
  value       = module.threat_surface_iam.compromised_access_key_id
}

output "compromised_secret_access_key" {
  description = "Leaked secret key used to seed the kill-chain simulation"
  value       = module.threat_surface_iam.compromised_secret_access_key
  sensitive   = true
}

output "pivot_role_arn" {
  description = "ARN of the pivot role targeted during lateral movement"
  value       = module.threat_surface_iam.pivot_role_arn
}

output "sensitive_data_bucket" {
  description = "Name of the sensitive-data bucket targeted during exfiltration"
  value       = module.threat_surface_s3.bucket_name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID for querying findings after an attack run"
  value       = module.detection.guardduty_detector_id
}
