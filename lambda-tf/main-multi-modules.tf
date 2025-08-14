# Multi-Module Lambda Deployment Example
# This file demonstrates how to deploy multiple Lambda functions with different source code

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
    key            = "lambda-multi-modules/terraform.tfstate"
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

# S3 Event Forwarder Lambda (using dedicated module)
module "s3_forwarder_prod" {
  source = "./modules/lambda-s3-forwarder"

  function_name        = "prod-s3-event-forwarder"
  source_bucket_name   = "prod-application-bucket"
  runtime             = "python3.11"
  timeout             = 300
  memory_size         = 512
  environment         = "prod"
  description         = "Production S3 Event Forwarder"
  s3_prefix           = "uploads/"
  s3_suffix           = ".json"
  s3_events           = ["s3:ObjectCreated:*"]
  
  environment_variables = {
    LOG_LEVEL = "INFO"
    MAX_RETRIES = "3"
  }
  
  log_retention_days = 30
  enable_metrics    = true
  enable_alarms     = true
  error_threshold   = 1
  duration_threshold = 250000
  
  permission_boundary_arn = var.global_settings.default_permission_boundary_arn
  tags = merge(var.global_settings.default_tags, {
    FunctionType = "s3-forwarder"
    Environment  = "prod"
  })
  
  deployment_key = "prod-s3-forwarder"
}

module "s3_forwarder_staging" {
  source = "./modules/lambda-s3-forwarder"

  function_name        = "staging-s3-event-forwarder"
  source_bucket_name   = "staging-application-bucket"
  runtime             = "python3.11"
  timeout             = 180
  memory_size         = 256
  environment         = "staging"
  description         = "Staging S3 Event Forwarder"
  s3_prefix           = "test-data/"
  s3_events           = ["s3:ObjectCreated:*"]
  
  environment_variables = {
    LOG_LEVEL = "DEBUG"
  }
  
  log_retention_days = 7
  enable_metrics    = true
  enable_alarms     = true
  error_threshold   = 1
  duration_threshold = 180000
  
  tags = merge(var.global_settings.default_tags, {
    FunctionType = "s3-forwarder"
    Environment  = "staging"
  })
  
  deployment_key = "staging-s3-forwarder"
}

# Image Processor Lambda (using dedicated module)
module "image_processor_prod" {
  source = "./modules/lambda-image-processor"

  function_name        = "prod-image-processor"
  source_bucket_name   = "prod-images-bucket"
  output_bucket_name   = "prod-processed-images-bucket"
  runtime             = "python3.11"
  timeout             = 900  # 15 minutes for image processing
  memory_size         = 2048 # More memory for image processing
  environment         = "prod"
  description         = "Production Image Processor"
  s3_prefix           = "uploads/images/"
  s3_suffix           = ".jpg"
  s3_events           = ["s3:ObjectCreated:*"]
  
  environment_variables = {
    LOG_LEVEL = "INFO"
    IMAGE_QUALITY = "85"
    MAX_WIDTH = "1920"
    MAX_HEIGHT = "1080"
  }
  
  log_retention_days = 30
  enable_metrics    = true
  enable_alarms     = true
  error_threshold   = 1
  duration_threshold = 600000 # 10 minutes
  
  permission_boundary_arn = var.global_settings.default_permission_boundary_arn
  tags = merge(var.global_settings.default_tags, {
    FunctionType = "image-processor"
    Environment  = "prod"
  })
  
  deployment_key = "prod-image-processor"
}

module "image_processor_staging" {
  source = "./modules/lambda-image-processor"

  function_name        = "staging-image-processor"
  source_bucket_name   = "staging-images-bucket"
  output_bucket_name   = "staging-processed-images-bucket"
  runtime             = "python3.11"
  timeout             = 600  # 10 minutes for staging
  memory_size         = 1024 # Less memory for staging
  environment         = "staging"
  description         = "Staging Image Processor"
  s3_prefix           = "test-images/"
  s3_suffix           = ".jpg"
  s3_events           = ["s3:ObjectCreated:*"]
  
  environment_variables = {
    LOG_LEVEL = "DEBUG"
    IMAGE_QUALITY = "70"
    MAX_WIDTH = "1280"
    MAX_HEIGHT = "720"
  }
  
  log_retention_days = 7
  enable_metrics    = true
  enable_alarms     = true
  error_threshold   = 1
  duration_threshold = 300000 # 5 minutes
  
  tags = merge(var.global_settings.default_tags, {
    FunctionType = "image-processor"
    Environment  = "staging"
  })
  
  deployment_key = "staging-image-processor"
}

# Example of how to add more Lambda modules:
# module "data_transformer" {
#   source = "./modules/lambda-data-transformer"
#   # ... configuration
# }
# 
# module "notification_service" {
#   source = "./modules/lambda-notification"
#   # ... configuration
# } 