# Overprivileged IAM user (simulates compromised credentials)
resource "aws_iam_user" "compromised" {
  name = "${var.project_name}-compromised-user"

  tags = {
    Name = "${var.project_name}-compromised-user"
  }
}

resource "aws_iam_access_key" "compromised" {
  user = aws_iam_user.compromised.name
}

# Overprivileged policy attached directly to user (no permissions boundary)
resource "aws_iam_user_policy" "compromised" {
  name = "${var.project_name}-overprivileged-policy"
  user = aws_iam_user.compromised.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OverprivilegedAccess"
        Effect = "Allow"
        Action = [
          "s3:*",
          "ec2:*",
          "iam:*",
          "sts:*",
          "logs:*",
          "cloudtrail:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Role that allows the compromised user to assume it (lateral movement)
resource "aws_iam_role" "pivot" {
  name = "${var.project_name}-pivot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.compromised.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-pivot-role"
  }
}

resource "aws_iam_role_policy" "pivot" {
  name = "${var.project_name}-pivot-policy"
  role = aws_iam_role.pivot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PivotAccess"
        Effect = "Allow"
        Action = [
          "s3:*",
          "ec2:*",
          "lambda:*"
        ]
        Resource = "*"
      }
    ]
  })
}