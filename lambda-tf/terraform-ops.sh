#!/bin/bash

# Terraform Operations Script for Jenkins Pipeline
# This script handles all Terraform operations with proper error handling and logging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <action> [options]"
    echo ""
    echo "Actions:"
    echo "  init     - Initialize Terraform"
    echo "  plan     - Create Terraform plan"
    echo "  apply    - Apply Terraform configuration"
    echo "  destroy  - Destroy Terraform resources"
    echo "  output   - Show Terraform outputs"
    echo ""
    echo "Options:"
    echo "  --bucket <bucket-name>     - S3 bucket for state storage"
    echo "  --key <state-key>          - State file key"
    echo "  --region <region>          - AWS region"
    echo "  --vars <var-file>          - Variables file (terraform.tfvars)"
    echo "  --auto-approve             - Auto approve for apply/destroy"
    echo "  --plan-file <file>         - Plan file for apply"
    echo ""
    echo "Examples:"
    echo "  $0 init --bucket my-bucket --key terraform.tfstate --region us-east-1"
    echo "  $0 plan --vars terraform.tfvars"
    echo "  $0 apply --plan-file tfplan --auto-approve"
    echo "  $0 destroy --vars terraform.tfvars --auto-approve"
}

# Function to validate required parameters
validate_params() {
    if [ -z "$ACTION" ]; then
        print_error "Action is required"
        show_usage
        exit 1
    fi
    
    if [ "$ACTION" = "init" ]; then
        if [ -z "$STATE_BUCKET" ] || [ -z "$STATE_KEY" ] || [ -z "$AWS_REGION" ]; then
            print_error "init action requires --bucket, --key, and --region parameters"
            show_usage
            exit 1
        fi
    fi
}

# Function to check if Terraform is installed
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    TERRAFORM_VERSION=$(terraform --version | head -n1)
    print_info "Using $TERRAFORM_VERSION"
}

# Function to initialize Terraform
terraform_init() {
    print_info "Initializing Terraform..."
    print_info "State bucket: $STATE_BUCKET"
    print_info "State key: $STATE_KEY"
    print_info "Region: $AWS_REGION"
    
    terraform init \
        -backend-config="bucket=$STATE_BUCKET" \
        -backend-config="key=$STATE_KEY" \
        -backend-config="region=$AWS_REGION"
    
    print_success "Terraform initialized successfully"
}

# Function to create Terraform plan
terraform_plan() {
    print_info "Creating Terraform plan..."
    
    PLAN_ARGS=""
    if [ -n "$VAR_FILE" ]; then
        PLAN_ARGS="-var-file=$VAR_FILE"
        print_info "Using variables file: $VAR_FILE"
    fi
    
    terraform plan $PLAN_ARGS -out=tfplan
    
    print_success "Terraform plan created successfully"
    print_info "Plan file saved as: tfplan"
}

# Function to apply Terraform configuration
terraform_apply() {
    print_info "Applying Terraform configuration..."
    
    if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
        print_info "Using plan file: $PLAN_FILE"
        terraform apply $PLAN_FILE
    else
        print_warning "No plan file specified, applying directly"
        APPLY_ARGS=""
        if [ -n "$VAR_FILE" ]; then
            APPLY_ARGS="-var-file=$VAR_FILE"
        fi
        if [ "$AUTO_APPROVE" = "true" ]; then
            APPLY_ARGS="$APPLY_ARGS -auto-approve"
        fi
        terraform apply $APPLY_ARGS
    fi
    
    print_success "Terraform configuration applied successfully"
}

# Function to destroy Terraform resources
terraform_destroy() {
    print_warning "Destroying Terraform resources..."
    print_warning "This action will permanently delete all resources!"
    
    DESTROY_ARGS=""
    if [ -n "$VAR_FILE" ]; then
        DESTROY_ARGS="-var-file=$VAR_FILE"
    fi
    if [ "$AUTO_APPROVE" = "true" ]; then
        DESTROY_ARGS="$DESTROY_ARGS -auto-approve"
    fi
    
    terraform destroy $DESTROY_ARGS
    
    print_success "Terraform resources destroyed successfully"
}

# Function to show Terraform outputs
terraform_output() {
    print_info "Showing Terraform outputs..."
    terraform output
}

# Function to validate Terraform configuration
terraform_validate() {
    print_info "Validating Terraform configuration..."
    terraform validate
    print_success "Terraform configuration is valid"
}

# Function to format Terraform code
terraform_fmt() {
    print_info "Formatting Terraform code..."
    terraform fmt -check
    print_success "Terraform code is properly formatted"
}

# Main script logic
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            init|plan|apply|destroy|output|validate|fmt)
                ACTION="$1"
                shift
                ;;
            --bucket)
                STATE_BUCKET="$2"
                shift 2
                ;;
            --key)
                STATE_KEY="$2"
                shift 2
                ;;
            --region)
                AWS_REGION="$2"
                shift 2
                ;;
            --vars)
                VAR_FILE="$2"
                shift 2
                ;;
            --auto-approve)
                AUTO_APPROVE="true"
                shift
                ;;
            --plan-file)
                PLAN_FILE="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate parameters
    validate_params
    
    # Check if Terraform is installed
    check_terraform
    
    # Validate and format Terraform code
    terraform_validate
    terraform_fmt
    
    # Execute the requested action
    case $ACTION in
        init)
            terraform_init
            ;;
        plan)
            terraform_plan
            ;;
        apply)
            terraform_apply
            ;;
        destroy)
            terraform_destroy
            ;;
        output)
            terraform_output
            ;;
        validate)
            print_success "Validation completed"
            ;;
        fmt)
            print_success "Formatting check completed"
            ;;
        *)
            print_error "Unknown action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 