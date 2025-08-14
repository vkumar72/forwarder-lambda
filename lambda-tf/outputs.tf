# Legacy outputs for backward compatibility
output "lambda_function_name" {
  description = "Name of the Lambda function (legacy)"
  value       = local.use_legacy_deployment ? module.lambda_s3_forwarder["legacy"].function_name : null
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function (legacy)"
  value       = local.use_legacy_deployment ? module.lambda_s3_forwarder["legacy"].function_arn : null
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role (legacy)"
  value       = local.use_legacy_deployment ? module.lambda_s3_forwarder["legacy"].role_arn : null
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name (legacy)"
  value       = local.use_legacy_deployment ? module.lambda_s3_forwarder["legacy"].log_group_name : null
}

output "s3_bucket_notification_id" {
  description = "S3 bucket notification ID (legacy)"
  value       = local.use_legacy_deployment ? module.lambda_s3_forwarder["legacy"].bucket_notification_id : null
}

# Terraform state bucket outputs
output "terraform_state_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = var.create_state_bucket ? aws_s3_bucket.terraform_state[0].bucket : data.aws_s3_bucket.terraform_state[0].bucket
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = var.create_state_bucket ? aws_s3_bucket.terraform_state[0].arn : data.aws_s3_bucket.terraform_state[0].arn
}

output "terraform_state_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = var.create_state_bucket && var.enable_state_locking ? aws_dynamodb_table.terraform_state_lock[0].name : null
}

# Multi-deployment outputs
output "lambda_deployments" {
  description = "Map of all deployed Lambda functions with their details"
  value = {
    for key, module in module.lambda_s3_forwarder : key => {
      function_name     = module.function_name
      function_arn      = module.function_arn
      role_arn          = module.role_arn
      log_group_name    = module.log_group_name
      bucket_notification_id = module.bucket_notification_id
      source_bucket_name = module.source_bucket_name
      environment       = module.environment
      vpc_config        = module.vpc_config
      is_vpc_enabled    = module.is_vpc_enabled
    }
  }
}

output "deployment_summary" {
  description = "Summary of all deployments"
  value = {
    total_deployments = length(module.lambda_s3_forwarder)
    deployments = [
      for key, module in module.lambda_s3_forwarder : {
        deployment_key = key
        function_name = module.function_name
        environment = module.environment
        source_bucket = module.source_bucket_name
        vpc_enabled = module.is_vpc_enabled
        vpc_id = module.vpc_config != null ? module.vpc_config.vpc_id : null
      }
    ]
    vpc_deployments = [
      for key, module in module.lambda_s3_forwarder : key
      if module.is_vpc_enabled
    ]
    non_vpc_deployments = [
      for key, module in module.lambda_s3_forwarder : key
      if !module.is_vpc_enabled
    ]
  }
}

output "cloudwatch_alarms" {
  description = "CloudWatch alarms for each deployment"
  value = {
    for key, module in module.lambda_s3_forwarder : key => {
      error_alarm_arn    = module.error_alarm_arn
      duration_alarm_arn = module.duration_alarm_arn
    }
  }
}

output "vpc_deployments" {
  description = "Deployments running in VPC"
  value = {
    for key, module in module.lambda_s3_forwarder : key => module.vpc_config
    if module.is_vpc_enabled
  }
}

output "vpc_summary" {
  description = "Summary of VPC configurations"
  value = {
    total_deployments = length(module.lambda_s3_forwarder)
    vpc_deployments = length([
      for key, module in module.lambda_s3_forwarder
      if module.is_vpc_enabled
    ])
    non_vpc_deployments = length([
      for key, module in module.lambda_s3_forwarder
      if !module.is_vpc_enabled
    ])
    vpc_ids = distinct([
      for key, module in module.lambda_s3_forwarder
      if module.is_vpc_enabled && module.vpc_config != null
      : module.vpc_config.vpc_id
    ])
  }
} 