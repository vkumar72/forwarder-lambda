#!/bin/bash

# Script to initialize Terraform state bucket
# This script helps set up the S3 bucket for Terraform state storage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if required parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <bucket-name> <region> [enable-locking]"
    echo "Example: $0 my-terraform-state-bucket us-east-1 true"
    exit 1
fi

BUCKET_NAME=$1
REGION=$2
ENABLE_LOCKING=${3:-false}

print_status "Initializing Terraform state bucket: $BUCKET_NAME in region: $REGION"

# Check if bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    print_warning "Bucket $BUCKET_NAME already exists!"
    read -p "Do you want to continue with the existing bucket? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Exiting..."
        exit 0
    fi
else
    print_status "Creating S3 bucket: $BUCKET_NAME"
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
fi

# Enable versioning
print_status "Enabling versioning on bucket: $BUCKET_NAME"
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
print_status "Enabling server-side encryption on bucket: $BUCKET_NAME"
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Block public access
print_status "Blocking public access on bucket: $BUCKET_NAME"
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking if requested
if [ "$ENABLE_LOCKING" = "true" ]; then
    TABLE_NAME="${BUCKET_NAME}-lock"
    print_status "Creating DynamoDB table for state locking: $TABLE_NAME"
    
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
    
    print_status "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
    print_status "DynamoDB table $TABLE_NAME is now active"
fi

print_status "Terraform state bucket setup completed successfully!"
print_status "Bucket: $BUCKET_NAME"
print_status "Region: $REGION"
if [ "$ENABLE_LOCKING" = "true" ]; then
    print_status "State locking: Enabled (DynamoDB table: ${BUCKET_NAME}-lock)"
else
    print_status "State locking: Disabled"
fi

echo
print_status "Next steps:"
echo "1. Update your terraform.tfvars file with:"
echo "   terraform_state_bucket = \"$BUCKET_NAME\""
echo "   create_state_bucket = false"
if [ "$ENABLE_LOCKING" = "true" ]; then
    echo "   enable_state_locking = true"
fi
echo "2. Run: terraform init"
echo "3. Run: terraform plan" 