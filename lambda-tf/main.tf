terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = var.terraform_state_bucket
    key            = "lambda-s3-forwarder/terraform.tfstate"
    region         = var.aws_region
    encrypt        = true
    dynamodb_table = var.enable_state_locking ? "${var.terraform_state_bucket}-lock" : null
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Conditional state bucket creation
data "aws_s3_bucket" "terraform_state" {
  count  = var.create_state_bucket ? 0 : 1
  bucket = var.terraform_state_bucket
}

# Data source for current region
data "aws_region" "current" {}

# Data source for VPC (if VPC configuration is provided)
data "aws_vpc" "lambda_vpc" {
  count = var.global_settings.default_vpc_config != null ? 1 : 0
  id    = var.global_settings.default_vpc_config.vpc_id
}

# Data source for subnets (if VPC configuration is provided)
data "aws_subnets" "lambda_subnets" {
  count = var.global_settings.default_vpc_config != null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.global_settings.default_vpc_config.vpc_id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]  # Use private subnets for Lambda
  }
}

# Data source for security groups (if VPC configuration is provided)
data "aws_security_groups" "lambda_security_groups" {
  count = var.global_settings.default_vpc_config != null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.global_settings.default_vpc_config.vpc_id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["lambda-security-group"]
  }
}

# Local values for managing deployment configurations
locals {
  # Determine if we should use legacy single deployment or multi-deployment
  use_legacy_deployment = var.lambda_deployments == null || length(var.lambda_deployments) == 0
  
  # Merge global settings with deployment-specific settings
  deployment_configs = local.use_legacy_deployment ? {
    "legacy" = {
      function_name        = var.function_name
      source_bucket_name   = var.source_bucket_name
      runtime             = var.runtime
      timeout             = var.timeout
      memory_size         = var.memory_size
      environment         = var.environment
      description         = "Legacy S3 Event Forwarder Lambda"
      reserved_concurrency = null
      s3_events           = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
      s3_prefix           = null
      s3_suffix           = null
      environment_variables = {}
      log_retention_days  = var.global_settings.default_log_retention
      enable_metrics      = var.global_settings.default_enable_metrics
      enable_alarms       = var.global_settings.default_enable_alarms
      error_threshold     = var.global_settings.default_error_threshold
      duration_threshold  = var.global_settings.default_duration_threshold
      permission_boundary_arn = var.global_settings.default_permission_boundary_arn
      vpc_config          = var.global_settings.default_vpc_config
      tags                = merge(var.global_settings.default_tags, {
        DeploymentType = "legacy"
      })
    }
  } : {
    for key, deployment in var.lambda_deployments : key => merge({
      # Default values from global settings
      runtime             = var.global_settings.default_runtime
      timeout             = var.global_settings.default_timeout
      memory_size         = var.global_settings.default_memory_size
      description         = "S3 Event Forwarder Lambda Function"
      reserved_concurrency = null
      s3_events           = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
      s3_prefix           = null
      s3_suffix           = null
      environment_variables = {}
      log_retention_days  = var.global_settings.default_log_retention
      enable_metrics      = var.global_settings.default_enable_metrics
      enable_alarms       = var.global_settings.default_enable_alarms
      error_threshold     = var.global_settings.default_error_threshold
      duration_threshold  = var.global_settings.default_duration_threshold
      permission_boundary_arn = var.global_settings.default_permission_boundary_arn
      vpc_config          = var.global_settings.default_vpc_config
      tags                = var.global_settings.default_tags
    }, deployment)
  }
}

# Deploy Lambda functions using the module
module "lambda_s3_forwarder" {
  for_each = local.deployment_configs
  source   = "./modules/lambda"

  function_name        = each.value.function_name
  source_bucket_name   = each.value.source_bucket_name
  runtime             = each.value.runtime
  timeout             = each.value.timeout
  memory_size         = each.value.memory_size
  environment         = each.value.environment
  description         = each.value.description
  reserved_concurrency = each.value.reserved_concurrency
  s3_events           = each.value.s3_events
  s3_prefix           = each.value.s3_prefix
  s3_suffix           = each.value.s3_suffix
  environment_variables = each.value.environment_variables
  log_retention_days  = each.value.log_retention_days
  enable_metrics      = each.value.enable_metrics
  enable_alarms       = each.value.enable_alarms
  error_threshold     = each.value.error_threshold
  duration_threshold  = each.value.duration_threshold
  permission_boundary_arn = each.value.permission_boundary_arn
  vpc_config          = each.value.vpc_config
  tags                = merge(each.value.tags, {
    DeploymentKey = each.key
  })
  deployment_key      = each.key
} 