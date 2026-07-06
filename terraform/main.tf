module "threat_surface_vpc" {
  source = "./modules/threat-surface-vpc"

  project_name = var.project_name
  environment  = var.environment
}

module "threat_surface_ec2" {
  source = "./modules/threat-surface-ec2"

  project_name      = var.project_name
  environment       = var.environment
  subnet_id         = module.threat_surface_vpc.public_subnet_id
  security_group_id = module.threat_surface_vpc.permissive_sg_id
}

module "threat_surface_s3" {
  source = "./modules/threat-surface-s3"

  project_name = var.project_name
  environment  = var.environment
}

module "threat_surface_iam" {
  source = "./modules/threat-surface-iam"

  project_name = var.project_name
  environment  = var.environment
}

module "detection" {
  source = "./modules/detection"

  project_name  = var.project_name
  environment   = var.environment
  s3_bucket_arn = module.threat_surface_s3.bucket_arn
}

module "siem" {
  source                    = "./modules/siem"
  project_name              = var.project_name
  environment               = var.environment
  cloudtrail_log_group_name = module.detection.cloudtrail_log_group_name
  cloudtrail_log_group_arn  = module.detection.cloudtrail_log_group_arn
  flow_logs_log_group_name  = module.threat_surface_vpc.flow_logs_log_group_name
  flow_logs_log_group_arn   = module.threat_surface_vpc.flow_logs_log_group_arn
  my_ip                     = var.my_ip
}

module "remediation" {
  source = "./modules/remediation"

  project_name       = var.project_name
  environment        = var.environment
  notification_email = var.notification_email
  threat_instance_id = module.threat_surface_ec2.instance_id
  permissive_sg_id   = module.threat_surface_vpc.permissive_sg_id
  vpc_id             = module.threat_surface_vpc.vpc_id
}