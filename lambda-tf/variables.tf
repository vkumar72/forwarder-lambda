variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "create_state_bucket" {
  description = "Whether to create the Terraform state bucket"
  type        = bool
  default     = false
}

variable "enable_state_locking" {
  description = "Whether to enable DynamoDB state locking"
  type        = bool
  default     = false
}

variable "lambda_deployments" {
  description = "Map of Lambda deployments"
  type = map(object({
    function_name        = string
    source_bucket_name   = string
    runtime             = optional(string)
    timeout             = optional(number)
    memory_size         = optional(number)
    environment         = string
    description         = optional(string)
    reserved_concurrency = optional(number)
    s3_events           = optional(list(string))
    s3_prefix           = optional(string)
    s3_suffix           = optional(string)
    environment_variables = optional(map(string))
    log_retention_days  = optional(number)
    enable_metrics      = optional(bool)
    enable_alarms       = optional(bool)
    error_threshold     = optional(number)
    duration_threshold  = optional(number)
    permission_boundary_arn = optional(string)
    vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    tags = optional(map(string))
  }))
  default = {}
}

# Legacy variables for backward compatibility
variable "source_bucket_name" {
  description = "Source S3 bucket name (legacy)"
  type        = string
  default     = null
}

variable "function_name" {
  description = "Lambda function name (legacy)"
  type        = string
  default     = null
}

variable "runtime" {
  description = "Lambda runtime (legacy)"
  type        = string
  default     = null
}

variable "timeout" {
  description = "Lambda timeout in seconds (legacy)"
  type        = number
  default     = null
}

variable "memory_size" {
  description = "Lambda memory size in MB (legacy)"
  type        = number
  default     = null
}

variable "environment" {
  description = "Environment name (legacy)"
  type        = string
  default     = null
}

variable "global_settings" {
  description = "Global settings for all deployments"
  type = object({
    default_runtime              = string
    default_timeout              = number
    default_memory_size          = number
    default_log_retention        = number
    default_enable_metrics       = bool
    default_enable_alarms        = bool
    default_error_threshold      = number
    default_duration_threshold   = number
    default_permission_boundary_arn = optional(string)
    default_vpc_config = optional(object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
    default_tags = map(string)
  })
  default = {
    default_runtime            = "python3.11"
    default_timeout            = 300
    default_memory_size        = 512
    default_log_retention      = 30
    default_enable_metrics     = true
    default_enable_alarms      = true
    default_error_threshold    = 1
    default_duration_threshold = 250000
    default_tags = {
      Environment = "prod"
      Project     = "s3-event-forwarder"
      ManagedBy   = "terraform"
    }
  }
} 