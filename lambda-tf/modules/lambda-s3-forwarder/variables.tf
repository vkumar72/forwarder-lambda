variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "source_bucket_name" {
  description = "Name of the S3 bucket to monitor"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 300
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "description" {
  description = "Lambda function description"
  type        = string
  default     = "S3 Event Forwarder Lambda Function"
}

variable "reserved_concurrency" {
  description = "Reserved concurrency limit"
  type        = number
  default     = null
}

variable "s3_events" {
  description = "S3 events to trigger Lambda"
  type        = list(string)
  default     = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
}

variable "s3_prefix" {
  description = "S3 object key prefix filter"
  type        = string
  default     = null
}

variable "s3_suffix" {
  description = "S3 object key suffix filter"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_metrics" {
  description = "Enable CloudWatch metrics and dashboard"
  type        = bool
  default     = true
}

variable "enable_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "error_threshold" {
  description = "Error threshold for CloudWatch alarm"
  type        = number
  default     = 1
}

variable "duration_threshold" {
  description = "Duration threshold for CloudWatch alarm (milliseconds)"
  type        = number
  default     = 250000
}

variable "permission_boundary_arn" {
  description = "Permission boundary ARN for IAM role"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "deployment_key" {
  description = "Deployment key for identification"
  type        = string
  default     = "default"
} 