# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    athena         = "http://localhost:4566"
    cloudtrail     = "http://localhost:4566"
    iam            = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    sts            = "http://localhost:4566"
    glue           = "http://localhost:4566"
  }
}

# S3 Bucket: Stores CloudTrail audit logs
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "sysops-audit-logs-bucket"
  force_destroy = true
}

# S3 Bucket Policy: Allows CloudTrail to write logs to the bucket
resource "aws_s3_bucket_policy" "audit_logs_policy" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# S3 Bucket: Stores Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket        = "sysops-athena-results-bucket"
  force_destroy = true
}

# CloudTrail: Records all API activity in the account
resource "aws_cloudtrail" "main_trail" {
  name                          = "management-events-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.audit_logs_policy]
}

# Athena Database: Logical container for our audit tables
resource "aws_athena_database" "audit_db" {
  name   = "cloudtrail_audit_db"
  bucket = aws_s3_bucket.athena_results.id
}

# Athena Workgroup: Manages query execution settings
resource "aws_athena_workgroup" "audit_workgroup" {
  name = "forensic-auditing"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
  }
}

# Outputs: Key identifiers for forensic auditing
output "audit_log_bucket" {
  value = aws_s3_bucket.audit_logs.id
}

output "athena_db_name" {
  value = aws_athena_database.audit_db.name
}
