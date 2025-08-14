# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = var.terraform_state_bucket

  tags = merge(var.tags, {
    Name = "terraform-state-bucket"
    Purpose = "Terraform State Storage"
  })
}

# S3 Bucket Versioning for State Bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption for State Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block for State Bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration for State Bucket
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count  = var.create_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    id     = "state-retention"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# DynamoDB Table for State Locking (Optional)
resource "aws_dynamodb_table" "terraform_state_lock" {
  count          = var.create_state_bucket && var.enable_state_locking ? 1 : 0
  name           = "${var.terraform_state_bucket}-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.tags, {
    Name = "terraform-state-lock"
    Purpose = "Terraform State Locking"
  })
} 