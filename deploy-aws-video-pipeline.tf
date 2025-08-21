# AWS Video Processing Pipeline for VAST-TAMS Integration
# Automatically processes videos uploaded to VAST storage using AWS Rekognition

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "tams_api_url" {
  description = "TAMS API endpoint"
  type        = string
  default     = "http://34.216.9.25:8000"
}

variable "vast_endpoint" {
  description = "VAST S3 endpoint"
  type        = string
  default     = "http://10.0.11.161:9090"
}

variable "vast_bucket" {
  description = "VAST storage bucket name"
  type        = string
  default     = "tams-storage"
}

# IAM Role for Lambda
resource "aws_iam_role" "video_processor_role" {
  name = "video-processor-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "video_processor_policy" {
  name = "video-processor-policy"
  role = aws_iam_role.video_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rekognition:StartLabelDetection",
          "rekognition:StartTextDetection",
          "rekognition:GetLabelDetection",
          "rekognition:GetTextDetection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::${var.vast_bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${var.vast_bucket}"
      }
    ]
  })
}

# Lambda function package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda-video-processor.py"
  output_path = "${path.module}/lambda-video-processor.zip"
}

# Lambda function
resource "aws_lambda_function" "video_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "vast-tams-video-processor"
  role            = aws_iam_role.video_processor_role.arn
  handler         = "lambda-video-processor.lambda_handler"
  runtime         = "python3.9"
  timeout         = 900  # 15 minutes
  memory_size     = 512

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TAMS_API_URL          = var.tams_api_url
      VAST_ENDPOINT         = var.vast_endpoint
      CONFIDENCE_THRESHOLD  = "70"
    }
  }

  depends_on = [
    aws_iam_role_policy.video_processor_policy
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "video_processor_logs" {
  name              = "/aws/lambda/vast-tams-video-processor"
  retention_in_days = 7
}

# S3 bucket for VAST integration (if needed)
resource "aws_s3_bucket" "vast_integration" {
  bucket = var.vast_bucket
}

# S3 bucket notification to trigger Lambda
resource "aws_s3_bucket_notification" "video_upload_notification" {
  bucket = aws_s3_bucket.vast_integration.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "nvidia-ai/"
    filter_suffix       = ".mp4"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "nvidia-ai/"
    filter_suffix       = ".avi"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "nvidia-ai/"
    filter_suffix       = ".mov"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.vast_integration.arn
}

# SNS Topic for notifications (optional)
resource "aws_sns_topic" "video_processing_notifications" {
  name = "vast-tams-video-processing"
}

# SQS Dead Letter Queue for failed Lambda executions
resource "aws_sqs_queue" "video_processor_dlq" {
  name = "vast-tams-video-processor-dlq"
  
  message_retention_seconds = 1209600  # 14 days
}

# CloudWatch Dashboard for monitoring
resource "aws_cloudwatch_dashboard" "video_processing_dashboard" {
  dashboard_name = "VAST-TAMS-Video-Processing"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.video_processor.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.video_processor.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.video_processor.function_name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Performance Metrics"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/lambda/vast-tams-video-processor'\n| fields @timestamp, @message\n| sort @timestamp desc\n| limit 100"
          region  = var.aws_region
          title   = "Recent Lambda Logs"
          view    = "table"
        }
      }
    ]
  })
}

# Outputs
output "lambda_function_arn" {
  description = "ARN of the video processing Lambda function"
  value       = aws_lambda_function.video_processor.arn
}

output "lambda_function_name" {
  description = "Name of the video processing Lambda function"
  value       = aws_lambda_function.video_processor.function_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for video storage"
  value       = aws_s3_bucket.vast_integration.bucket
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.video_processing_dashboard.dashboard_name}"
}