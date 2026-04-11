resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.project_name}-sensitive-data-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-sensitive-data"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = aws_s3_bucket.this.id
  depends_on = [aws_s3_bucket_public_access_block.this]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.this.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "sensitive_file" {
  bucket  = aws_s3_bucket.this.id
  key     = "confidential/customer-records.csv"
  content = <<-EOF
    id,name,email,ssn
    1,John Doe,john@example.com,123-45-6789
    2,Jane Smith,jane@example.com,987-65-4321
    3,Bob Wilson,bob@example.com,555-12-3456
  EOF

  tags = {
    Name = "simulated-sensitive-data"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}