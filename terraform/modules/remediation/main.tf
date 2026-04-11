data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# SNS topic for security alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-security-alerts"

  tags = {
    Name = "${var.project_name}-security-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Quarantine security group (deny all traffic)
resource "aws_security_group" "quarantine" {
  name        = "${var.project_name}-quarantine-sg"
  description = "Quarantine SG that blocks all traffic for compromised instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-quarantine-sg"
  }
}

# Lambda execution role
resource "aws_iam_role" "remediation" {
  name = "${var.project_name}-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-remediation-role"
  }
}

resource "aws_iam_role_policy" "remediation" {
  name = "${var.project_name}-remediation-policy"
  role = aws_iam_role.remediation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Remediation"
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMRemediation"
        Effect = "Allow"
        Action = [
          "iam:PutUserPolicy",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
          "iam:UpdateAccessKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Remediation"
        Effect = "Allow"
        Action = [
          "s3:PutBucketPolicy",
          "s3:PutPublicAccessBlock"
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# Lambda: Isolate compromised EC2 instance
data "archive_file" "isolate_instance" {
  type        = "zip"
  output_path = "${path.module}/lambda/isolate_instance.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import os
from datetime import datetime

ec2 = boto3.client('ec2')
sns = boto3.client('sns')

def handler(event, context):
    print(json.dumps(event))

    detail = event.get('detail', {})
    instance_id = os.environ['THREAT_INSTANCE_ID']
    quarantine_sg = os.environ['QUARANTINE_SG_ID']
    sns_topic = os.environ['SNS_TOPIC_ARN']

    try:
        ec2.modify_instance_attribute(
            InstanceId=instance_id,
            Groups=[quarantine_sg]
        )

        ec2.stop_instances(InstanceIds=[instance_id])

        message = (
            f"AUTOMATED REMEDIATION EXECUTED\n"
            f"Time: {datetime.utcnow().isoformat()}Z\n"
            f"Action: Instance isolated and stopped\n"
            f"Instance: {instance_id}\n"
            f"Quarantine SG: {quarantine_sg}\n"
            f"GuardDuty Finding: {detail.get('type', 'Unknown')}\n"
            f"Severity: {detail.get('severity', 'Unknown')}"
        )

        sns.publish(
            TopicArn=sns_topic,
            Subject=f"[{os.environ.get('PROJECT_NAME', 'cloud-security-lab')}] EC2 Instance Isolated",
            Message=message
        )

        return {'statusCode': 200, 'body': 'Instance isolated and stopped'}

    except Exception as e:
        print(f"Remediation failed: {str(e)}")
        raise
PYTHON
    filename = "isolate_instance.py"
  }
}

resource "aws_lambda_function" "isolate_instance" {
  function_name    = "${var.project_name}-isolate-instance"
  role             = aws_iam_role.remediation.arn
  handler          = "isolate_instance.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.isolate_instance.output_path
  source_code_hash = data.archive_file.isolate_instance.output_base64sha256

  environment {
    variables = {
      THREAT_INSTANCE_ID = var.threat_instance_id
      QUARANTINE_SG_ID   = aws_security_group.quarantine.id
      SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
      PROJECT_NAME       = var.project_name
    }
  }

  tags = {
    Name = "${var.project_name}-isolate-instance"
  }
}

# Lambda: Disable compromised IAM access keys
data "archive_file" "disable_iam_keys" {
  type        = "zip"
  output_path = "${path.module}/lambda/disable_iam_keys.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import os
from datetime import datetime

iam = boto3.client('iam')
sns = boto3.client('sns')

def handler(event, context):
    print(json.dumps(event))

    detail = event.get('detail', {})
    resource = detail.get('resource', {})
    access_key_details = resource.get('accessKeyDetails', {})
    username = access_key_details.get('userName', 'Unknown')
    sns_topic = os.environ['SNS_TOPIC_ARN']

    try:
        keys = iam.list_access_keys(UserName=username)

        for key in keys['AccessKeyMetadata']:
            iam.update_access_key(
                UserName=username,
                AccessKeyId=key['AccessKeyId'],
                Status='Inactive'
            )
            print(f"Disabled key {key['AccessKeyId']} for user {username}")

        deny_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Deny",
                    "Action": "*",
                    "Resource": "*"
                }
            ]
        }

        iam.put_user_policy(
            UserName=username,
            PolicyName='DenyAll-Remediation',
            PolicyDocument=json.dumps(deny_policy)
        )

        message = (
            f"AUTOMATED REMEDIATION EXECUTED\n"
            f"Time: {datetime.utcnow().isoformat()}Z\n"
            f"Action: IAM access keys disabled and deny all policy applied\n"
            f"User: {username}\n"
            f"GuardDuty Finding: {detail.get('type', 'Unknown')}\n"
            f"Severity: {detail.get('severity', 'Unknown')}"
        )

        sns.publish(
            TopicArn=sns_topic,
            Subject=f"[{os.environ.get('PROJECT_NAME', 'cloud-security-lab')}] IAM Credentials Disabled",
            Message=message
        )

        return {'statusCode': 200, 'body': f'Keys disabled for {username}'}

    except Exception as e:
        print(f"Remediation failed: {str(e)}")
        raise
PYTHON
    filename = "disable_iam_keys.py"
  }
}

resource "aws_lambda_function" "disable_iam_keys" {
  function_name    = "${var.project_name}-disable-iam-keys"
  role             = aws_iam_role.remediation.arn
  handler          = "disable_iam_keys.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.disable_iam_keys.output_path
  source_code_hash = data.archive_file.disable_iam_keys.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      PROJECT_NAME  = var.project_name
    }
  }

  tags = {
    Name = "${var.project_name}-disable-iam-keys"
  }
}

# Lambda: Lock down public S3 bucket
data "archive_file" "lockdown_s3" {
  type        = "zip"
  output_path = "${path.module}/lambda/lockdown_s3.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import os
from datetime import datetime

s3 = boto3.client('s3')
sns = boto3.client('sns')

def handler(event, context):
    print(json.dumps(event))

    detail = event.get('detail', {})
    resource = detail.get('resource', {})
    s3_details = resource.get('s3BucketDetails', [{}])[0]
    bucket_name = s3_details.get('name', 'Unknown')
    sns_topic = os.environ['SNS_TOPIC_ARN']

    try:
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )

        deny_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "DenyAllExceptRemediation",
                    "Effect": "Deny",
                    "Principal": "*",
                    "Action": "s3:*",
                    "Resource": [
                        f"arn:aws:s3:::{bucket_name}",
                        f"arn:aws:s3:::{bucket_name}/*"
                    ],
                    "Condition": {
                        "StringNotEquals": {
                            "aws:PrincipalAccount": os.environ.get('ACCOUNT_ID', '')
                        }
                    }
                }
            ]
        }

        s3.put_bucket_policy(
            Bucket=bucket_name,
            Policy=json.dumps(deny_policy)
        )

        message = (
            f"AUTOMATED REMEDIATION EXECUTED\n"
            f"Time: {datetime.utcnow().isoformat()}Z\n"
            f"Action: S3 bucket locked down\n"
            f"Bucket: {bucket_name}\n"
            f"GuardDuty Finding: {detail.get('type', 'Unknown')}\n"
            f"Severity: {detail.get('severity', 'Unknown')}"
        )

        sns.publish(
            TopicArn=sns_topic,
            Subject=f"[{os.environ.get('PROJECT_NAME', 'cloud-security-lab')}] S3 Bucket Locked Down",
            Message=message
        )

        return {'statusCode': 200, 'body': f'Bucket {bucket_name} locked down'}

    except Exception as e:
        print(f"Remediation failed: {str(e)}")
        raise
PYTHON
    filename = "lockdown_s3.py"
  }
}

resource "aws_lambda_function" "lockdown_s3" {
  function_name    = "${var.project_name}-lockdown-s3"
  role             = aws_iam_role.remediation.arn
  handler          = "lockdown_s3.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.lockdown_s3.output_path
  source_code_hash = data.archive_file.lockdown_s3.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      PROJECT_NAME  = var.project_name
      ACCOUNT_ID    = data.aws_caller_identity.current.account_id
    }
  }

  tags = {
    Name = "${var.project_name}-lockdown-s3"
  }
}

# EventBridge rule: GuardDuty EC2 findings
resource "aws_cloudwatch_event_rule" "guardduty_ec2" {
  name        = "${var.project_name}-guardduty-ec2-findings"
  description = "Triggers on GuardDuty EC2 related findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [{ prefix = "UnauthorizedAccess:EC2" }, { prefix = "Recon:EC2" }]
      severity = [{ numeric = [">=", 5] }]
    }
  })

  tags = {
    Name = "${var.project_name}-guardduty-ec2-rule"
  }
}

resource "aws_cloudwatch_event_target" "isolate_instance" {
  rule = aws_cloudwatch_event_rule.guardduty_ec2.name
  arn  = aws_lambda_function.isolate_instance.arn
}

resource "aws_lambda_permission" "guardduty_ec2" {
  statement_id  = "AllowEventBridgeGuardDutyEC2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.isolate_instance.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_ec2.arn
}

# EventBridge rule: GuardDuty IAM findings
resource "aws_cloudwatch_event_rule" "guardduty_iam" {
  name        = "${var.project_name}-guardduty-iam-findings"
  description = "Triggers on GuardDuty IAM related findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [{ prefix = "UnauthorizedAccess:IAMUser" }, { prefix = "Discovery:IAMUser" }, { prefix = "Persistence:IAMUser" }]
      severity = [{ numeric = [">=", 5] }]
    }
  })

  tags = {
    Name = "${var.project_name}-guardduty-iam-rule"
  }
}

resource "aws_cloudwatch_event_target" "disable_iam_keys" {
  rule = aws_cloudwatch_event_rule.guardduty_iam.name
  arn  = aws_lambda_function.disable_iam_keys.arn
}

resource "aws_lambda_permission" "guardduty_iam" {
  statement_id  = "AllowEventBridgeGuardDutyIAM"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.disable_iam_keys.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_iam.arn
}

# EventBridge rule: GuardDuty S3 findings
resource "aws_cloudwatch_event_rule" "guardduty_s3" {
  name        = "${var.project_name}-guardduty-s3-findings"
  description = "Triggers on GuardDuty S3 related findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = [{ prefix = "Policy:S3" }, { prefix = "Exfiltration:S3" }, { prefix = "UnauthorizedAccess:S3" }]
      severity = [{ numeric = [">=", 5] }]
    }
  })

  tags = {
    Name = "${var.project_name}-guardduty-s3-rule"
  }
}

resource "aws_cloudwatch_event_target" "lockdown_s3" {
  rule = aws_cloudwatch_event_rule.guardduty_s3.name
  arn  = aws_lambda_function.lockdown_s3.arn
}

resource "aws_lambda_permission" "guardduty_s3" {
  statement_id  = "AllowEventBridgeGuardDutyS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lockdown_s3.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_s3.arn
}