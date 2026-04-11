data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# OpenSearch domain
resource "aws_opensearch_domain" "this" {
  domain_name    = "${var.project_name}-siem"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 10
  }

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "es:*"
        Resource  = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.project_name}-siem/*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-siem"
  }
}

# IAM role for CloudWatch to stream logs to OpenSearch
resource "aws_iam_role" "log_streaming" {
  name = "${var.project_name}-log-streaming-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-log-streaming-role"
  }
}

resource "aws_iam_role_policy" "log_streaming" {
  name = "${var.project_name}-log-streaming-policy"
  role = aws_iam_role.log_streaming.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut"
        ]
        Resource = "${aws_opensearch_domain.this.arn}/*"
      }
    ]
  })
}

# CloudTrail log subscription to OpenSearch
resource "aws_cloudwatch_log_subscription_filter" "cloudtrail" {
  name            = "${var.project_name}-cloudtrail-to-opensearch"
  log_group_name  = var.cloudtrail_log_group_name
  filter_pattern  = ""
  destination_arn = aws_opensearch_domain.this.arn
  role_arn        = aws_iam_role.log_streaming.arn
}

# VPC Flow Logs subscription to OpenSearch
resource "aws_cloudwatch_log_subscription_filter" "flow_logs" {
  name            = "${var.project_name}-flowlogs-to-opensearch"
  log_group_name  = var.flow_logs_log_group_name
  filter_pattern  = ""
  destination_arn = aws_opensearch_domain.this.arn
  role_arn        = aws_iam_role.log_streaming.arn
}