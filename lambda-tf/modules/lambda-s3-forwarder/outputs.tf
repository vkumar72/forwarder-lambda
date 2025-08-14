output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.s3_forwarder.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.s3_forwarder.arn
}

output "role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "bucket_notification_id" {
  description = "ID of the S3 bucket notification"
  value       = aws_s3_bucket_notification.lambda_notification.id
}

output "source_bucket_name" {
  description = "Name of the source S3 bucket"
  value       = var.source_bucket_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "error_alarm_arn" {
  description = "ARN of the error CloudWatch alarm"
  value       = var.enable_alarms ? aws_cloudwatch_metric_alarm.lambda_errors[0].arn : null
}

output "duration_alarm_arn" {
  description = "ARN of the duration CloudWatch alarm"
  value       = var.enable_alarms ? aws_cloudwatch_metric_alarm.lambda_duration[0].arn : null
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = var.enable_metrics ? aws_cloudwatch_dashboard.lambda_dashboard[0].dashboard_arn : null
}

output "configuration" {
  description = "Lambda function configuration summary"
  value = {
    function_name     = aws_lambda_function.s3_forwarder.function_name
    function_arn      = aws_lambda_function.s3_forwarder.arn
    runtime           = aws_lambda_function.s3_forwarder.runtime
    timeout           = aws_lambda_function.s3_forwarder.timeout
    memory_size       = aws_lambda_function.s3_forwarder.memory_size
    environment       = var.environment
    source_bucket     = var.source_bucket_name
    s3_events         = var.s3_events
    s3_prefix         = var.s3_prefix
    s3_suffix         = var.s3_suffix
    log_retention     = var.log_retention_days
    enable_metrics    = var.enable_metrics
    enable_alarms     = var.enable_alarms
    deployment_key    = var.deployment_key
  }
} 