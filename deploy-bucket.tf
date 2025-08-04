# S3 Deployment Bucket for Vast Datalayer POC

# Create S3 bucket
resource "aws_s3_bucket" "deploy_bucket" {
  bucket = "vast-deploy-bucket"

  tags = {
    Name        = "vast-deploy-bucket"
    Environment = "poc"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "deploy_bucket_pab" {
  bucket = aws_s3_bucket.deploy_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for backup/recovery
resource "aws_s3_bucket_versioning" "deploy_bucket_versioning" {
  bucket = aws_s3_bucket.deploy_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "deploy_bucket_encryption" {
  bucket = aws_s3_bucket.deploy_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create bucket policy from JSON file with bucket name substitution
resource "aws_s3_bucket_policy" "deploy_bucket_policy" {
  bucket = aws_s3_bucket.deploy_bucket.id
  
  policy = replace(
    file("${path.module}/s3-security-policy.json"),
    "<bucket-name>",
    aws_s3_bucket.deploy_bucket.id
  )
}

# Outputs
output "deploy_bucket_name" {
  value       = aws_s3_bucket.deploy_bucket.id
  description = "Name of the deployment S3 bucket"
}

output "deploy_bucket_arn" {
  value       = aws_s3_bucket.deploy_bucket.arn
  description = "ARN of the deployment S3 bucket"
}

output "deploy_bucket_region" {
  value       = aws_s3_bucket.deploy_bucket.region
  description = "Region of the deployment S3 bucket"
}