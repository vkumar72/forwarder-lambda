#!/bin/bash

# S3 Event Forwarder Lambda Function Deployment Script
# This script deploys the S3 Event Forwarder Lambda function with S3 trigger

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="s3-event-forwarder"
TEMPLATE_FILE="cloudformation.yml"
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

# Default values
S3_BUCKET_NAME=""
S3_EVENT_PREFIX=""
S3_EVENT_SUFFIX=""
S3_EVENTS="s3:ObjectCreated:*,s3:ObjectRemoved:*"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy S3 Event Forwarder Lambda function with S3 trigger.

OPTIONS:
    -b, --bucket-name NAME     S3 bucket name to monitor (required)
    -p, --prefix PREFIX        S3 object key prefix to filter events (optional)
    -s, --suffix SUFFIX        S3 object key suffix to filter events (optional)
    -e, --events EVENTS        S3 events to trigger Lambda (default: s3:ObjectCreated:*,s3:ObjectRemoved:*)
    -r, --region REGION        AWS region (default: us-east-1)
    -n, --environment ENV      Environment name (default: prod)
    -h, --help                 Display this help message

EXAMPLES:
    # Deploy with default settings
    $0 -b my-s3-bucket

    # Deploy with specific prefix and suffix
    $0 -b my-s3-bucket -p "logs/" -s ".json"

    # Deploy with specific events
    $0 -b my-s3-bucket -e "s3:ObjectCreated:Put,s3:ObjectCreated:Post"

    # Deploy to different region and environment
    $0 -b my-s3-bucket -r us-west-2 -n staging

EOF
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check if template file exists
    if [ ! -f "$TEMPLATE_FILE" ]; then
        error "Template file $TEMPLATE_FILE not found in current directory."
        exit 1
    fi
    
    # Check if required files exist
    for file in main.py config.py destinations.py requirements.txt; do
        if [ ! -f "$file" ]; then
            error "Required file $file not found in current directory."
            exit 1
        fi
    done
    
    success "Prerequisites check passed"
}

# Function to validate parameters
validate_parameters() {
    log "Validating parameters..."
    
    if [ -z "$S3_BUCKET_NAME" ]; then
        error "S3 bucket name is required. Use -b or --bucket-name option."
        exit 1
    fi
    
    # Check if S3 bucket exists
    if ! aws s3api head-bucket --bucket "$S3_BUCKET_NAME" --region "$REGION" &> /dev/null; then
        error "S3 bucket $S3_BUCKET_NAME does not exist or is not accessible."
        exit 1
    fi
    
    success "Parameters validation passed"
}

# Function to package Lambda function
package_lambda() {
    log "Packaging Lambda function..."
    
    # Create temporary directory for packaging
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy Lambda function files
    cp main.py "$TEMP_DIR/"
    cp config.py "$TEMP_DIR/"
    cp destinations.py "$TEMP_DIR/"
    cp requirements.txt "$TEMP_DIR/"
    
    # Install dependencies
    if [ -f requirements.txt ]; then
        log "Installing Python dependencies..."
        pip install -r requirements.txt -t "$TEMP_DIR" --quiet
    fi
    
    # Create ZIP file
    cd "$TEMP_DIR"
    zip -r lambda-package.zip . -q
    cd - > /dev/null
    
    # Upload to S3
    S3_PACKAGE_KEY="lambda-packages/s3-event-forwarder-$(date +%Y%m%d-%H%M%S).zip"
    S3_PACKAGE_BUCKET="${STACK_NAME}-packages-${REGION}"
    
    # Create S3 bucket for packages if it doesn't exist
    aws s3 mb "s3://$S3_PACKAGE_BUCKET" --region "$REGION" 2>/dev/null || true
    
    # Upload package
    aws s3 cp "$TEMP_DIR/lambda-package.zip" "s3://$S3_PACKAGE_BUCKET/$S3_PACKAGE_KEY" \
        --region "$REGION" --quiet
    
    # Set global variables for CloudFormation
    LAMBDA_PACKAGE_BUCKET="$S3_PACKAGE_BUCKET"
    LAMBDA_PACKAGE_KEY="$S3_PACKAGE_KEY"
    
    success "Lambda function packaged and uploaded to s3://$LAMBDA_PACKAGE_BUCKET/$LAMBDA_PACKAGE_KEY"
}

# Function to deploy CloudFormation stack
deploy_stack() {
    log "Deploying CloudFormation stack..."
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &> /dev/null; then
        log "Stack exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$STACK_NAME" \
            --template-body "file://$TEMPLATE_FILE" \
            --parameters \
                ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
                ParameterKey=S3BucketName,ParameterValue="$S3_BUCKET_NAME" \
                ParameterKey=S3EventPrefix,ParameterValue="$S3_EVENT_PREFIX" \
                ParameterKey=S3EventSuffix,ParameterValue="$S3_EVENT_SUFFIX" \
                ParameterKey=S3Events,ParameterValue="$S3_EVENTS" \
                ParameterKey=LambdaPackageBucket,ParameterValue="$LAMBDA_PACKAGE_BUCKET" \
                ParameterKey=LambdaPackageKey,ParameterValue="$LAMBDA_PACKAGE_KEY" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
        
        log "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION"
    else
        log "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-body "file://$TEMPLATE_FILE" \
            --parameters \
                ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
                ParameterKey=S3BucketName,ParameterValue="$S3_BUCKET_NAME" \
                ParameterKey=S3EventPrefix,ParameterValue="$S3_EVENT_PREFIX" \
                ParameterKey=S3EventSuffix,ParameterValue="$S3_EVENT_SUFFIX" \
                ParameterKey=S3Events,ParameterValue="$S3_EVENTS" \
                ParameterKey=LambdaPackageBucket,ParameterValue="$LAMBDA_PACKAGE_BUCKET" \
                ParameterKey=LambdaPackageKey,ParameterValue="$LAMBDA_PACKAGE_KEY" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
        
        log "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION"
    fi
    
    success "CloudFormation stack deployment completed"
}

# Function to get stack outputs
get_stack_outputs() {
    log "Getting stack outputs..."
    
    OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs' \
        --output json)
    
    echo "$OUTPUTS" | jq -r '.[] | "\(.OutputKey): \(.OutputValue)"'
}

# Function to test the deployment
test_deployment() {
    log "Testing deployment..."
    
    # Get Lambda function name
    FUNCTION_NAME=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
        --output text)
    
    if [ -n "$FUNCTION_NAME" ]; then
        log "Lambda function name: $FUNCTION_NAME"
        
        # Test with a sample S3 event
        log "Testing with sample S3 event..."
        cat > test-event.json << EOF
{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3",
      "awsRegion": "$REGION",
      "eventTime": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
      "eventName": "ObjectCreated:Put",
      "s3": {
        "bucket": {
          "name": "$S3_BUCKET_NAME"
        },
        "object": {
          "key": "test/test-file.txt"
        }
      }
    }
  ]
}
EOF
        
        # Invoke Lambda function
        aws lambda invoke \
            --function-name "$FUNCTION_NAME" \
            --payload "file://test-event.json" \
            --region "$REGION" \
            response.json
        
        if [ -f response.json ]; then
            log "Lambda function response:"
            cat response.json | jq .
            rm -f response.json test-event.json
        fi
    else
        warning "Could not retrieve Lambda function name for testing"
    fi
}

# Main execution
main() {
    log "Starting S3 Event Forwarder Lambda deployment..."
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--bucket-name)
                S3_BUCKET_NAME="$2"
                shift 2
                ;;
            -p|--prefix)
                S3_EVENT_PREFIX="$2"
                shift 2
                ;;
            -s|--suffix)
                S3_EVENT_SUFFIX="$2"
                shift 2
                ;;
            -e|--events)
                S3_EVENTS="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -n|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # Validate parameters
    validate_parameters
    
    # Package Lambda function
    package_lambda
    
    # Deploy stack
    deploy_stack
    
    # Get outputs
    get_stack_outputs
    
    # Test deployment
    test_deployment
    
    success "S3 Event Forwarder Lambda deployment completed successfully!"
    log "Stack name: $STACK_NAME"
    log "Region: $REGION"
    log "Environment: $ENVIRONMENT"
    log "S3 bucket: $S3_BUCKET_NAME"
    log "Lambda package: s3://$LAMBDA_PACKAGE_BUCKET/$LAMBDA_PACKAGE_KEY"
}

# Run main function with all arguments
main "$@" 