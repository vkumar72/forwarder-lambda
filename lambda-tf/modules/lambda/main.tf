# Data source for the source S3 bucket
data "aws_s3_bucket" "source_bucket" {
  bucket = var.source_bucket_name
}

# Data source for current region
data "aws_region" "current" {}

# Create ZIP file for Lambda deployment
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "*.log"]
}

# Lambda function
resource "aws_lambda_function" "lambda_function" {
  filename                       = data.archive_file.lambda_zip.output_path
  function_name                  = var.function_name
  role                          = aws_iam_role.lambda_role.arn
  handler                       = "main.lambda_handler"
  runtime                       = var.runtime
  timeout                       = var.timeout
  memory_size                   = var.memory_size
  reserved_concurrency_limit    = var.reserved_concurrency
  description                   = var.description
  
  environment {
    variables = merge(var.environment_variables, {
      ENVIRONMENT   = var.environment
      SOURCE_BUCKET = var.source_bucket_name
      DEPLOYMENT_KEY = var.deployment_key
    })
  }

  # VPC Configuration (conditional)
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

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

  dynamic "permissions_boundary" {
    for_each = var.permission_boundary_arn != null ? [1] : []
    content {
      permissions_boundary = var.permission_boundary_arn
    }
  }

  tags = var.tags
}

# Attach basic execution role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution role (required for Lambda in VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for S3, SQS, SNS permissions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectAcl",
          "s3:GetBucketNotification",
          "s3:GetBucketNotificationConfiguration"
        ]
        Resource = [
          data.aws_s3_bucket.source_bucket.arn,
          "${data.aws_s3_bucket.source_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:SendMessageBatch",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Enabled" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Enabled" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = ["sqs.amazonaws.com", "sns.amazonaws.com"]
          }
        }
      }
    ]
  })
}

# Additional policy for Lambda-specific permissions
resource "aws_iam_role_policy" "lambda_destination_policy" {
  name = "${var.function_name}-destination-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${data.aws_s3_bucket.source_bucket.arn}/destinations.json"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = aws_lambda_function.lambda_function.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "lambda_notification" {
  bucket = data.aws_s3_bucket.source_bucket.id

  lambda_configuration {
    lambda_function_arn = aws_lambda_function.lambda_function.arn
    events              = var.s3_events

    dynamic "filter" {
      for_each = var.s3_prefix != null || var.s3_suffix != null ? [1] : []
      content {
        s3_key {
          rules = concat(
            var.s3_prefix != null ? [{
              name  = "prefix"
              value = var.s3_prefix
            }] : [],
            var.s3_suffix != null ? [{
              name  = "suffix"
              value = var.s3_suffix
            }] : []
          )
        }
      }
    }
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# Lambda permission for S3
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.source_bucket.arn
}

# CloudWatch alarms (conditional)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Lambda function errors"
  alarm_actions       = []
  ok_actions          = []

  dimensions = {
    FunctionName = aws_lambda_function.lambda_function.function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.duration_threshold
  alarm_description   = "Lambda function duration"
  alarm_actions       = []
  ok_actions          = []

  dimensions = {
    FunctionName = aws_lambda_function.lambda_function.function_name
  }

  tags = var.tags
}

# CloudWatch dashboard (conditional)
resource "aws_cloudwatch_dashboard" "lambda_dashboard" {
  count = var.enable_metrics ? 1 : 0

  dashboard_name = "${var.function_name}-dashboard"

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
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.lambda_function.function_name],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Lambda Function Metrics - ${var.function_name}"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.lambda_function.function_name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Lambda Function Duration - ${var.function_name}"
        }
      }
    ]
  })
} 