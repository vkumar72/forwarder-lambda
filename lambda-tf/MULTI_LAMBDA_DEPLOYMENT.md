# Multiple Lambda Deployments with Different Source Code

This document explains how to structure your Terraform configuration to deploy multiple Lambda functions with different source code and functionality.

## 📁 **Folder Structure Options**

### **Option 1: Multiple Lambda Modules (Recommended)**

This approach creates separate modules for each Lambda function type, allowing complete customization of source code, IAM permissions, and configuration.

```
lambda-tf/
├── main.tf                     # Main Terraform configuration
├── main-multi-modules.tf       # Example multi-module configuration
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
├── terraform.tfvars.example    # Example variable values
├── terraform-ops.sh           # Terraform operations script
├── Jenkinsfile                # Jenkins pipeline
├── README.md                  # Documentation
├── MULTI_LAMBDA_DEPLOYMENT.md # This file
└── modules/
    ├── lambda-s3-forwarder/    # S3 Event Forwarder Lambda
    │   ├── main.tf            # Module configuration
    │   ├── variables.tf       # Module variables
    │   ├── outputs.tf         # Module outputs
    │   └── src/               # Lambda source code
    │       ├── main.py        # Lambda handler
    │       ├── destinations.py # Destination management
    │       ├── destinations.json # Destination configuration
    │       ├── test_destinations.py # Test script
    │       └── requirements.txt # Python dependencies
    │
    ├── lambda-image-processor/ # Image Processing Lambda
    │   ├── main.tf            # Module configuration
    │   ├── variables.tf       # Module variables
    │   ├── outputs.tf         # Module outputs
    │   └── src/               # Lambda source code
    │       ├── main.py        # Lambda handler
    │       ├── image_processor.py # Image processing logic
    │       ├── config.json    # Image processing config
    │       └── requirements.txt # Python dependencies
    │
    ├── lambda-data-transformer/ # Data Transformation Lambda
    │   ├── main.tf            # Module configuration
    │   ├── variables.tf       # Module variables
    │   ├── outputs.tf         # Module outputs
    │   └── src/               # Lambda source code
    │       ├── main.py        # Lambda handler
    │       ├── transformer.py # Data transformation logic
    │       ├── schemas.json   # Data schemas
    │       └── requirements.txt # Python dependencies
    │
    └── lambda-notification/   # Notification Lambda
        ├── main.tf            # Module configuration
        ├── variables.tf       # Module variables
        ├── outputs.tf         # Module outputs
        └── src/               # Lambda source code
            ├── main.py        # Lambda handler
            ├── notification.py # Notification logic
            ├── templates.json # Notification templates
            └── requirements.txt # Python dependencies
```

### **Option 2: Shared Module with Source Code Symlinks**

This approach uses a shared module but references different source code directories.

```
lambda-tf/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
├── terraform-ops.sh
├── Jenkinsfile
├── README.md
├── modules/
│   └── lambda/                # Shared Lambda module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── src/               # Symlinks to actual source
│           ├── s3-forwarder/  # Symlink to ../../src/s3-forwarder/
│           ├── image-processor/ # Symlink to ../../src/image-processor/
│           ├── data-transformer/ # Symlink to ../../src/data-transformer/
│           └── notification/  # Symlink to ../../src/notification/
└── src/                       # Actual source code directories
    ├── s3-forwarder/
    │   ├── main.py
    │   ├── destinations.py
    │   ├── destinations.json
    │   └── requirements.txt
    ├── image-processor/
    │   ├── main.py
    │   ├── image_processor.py
    │   ├── config.json
    │   └── requirements.txt
    ├── data-transformer/
    │   ├── main.py
    │   ├── transformer.py
    │   ├── schemas.json
    │   └── requirements.txt
    └── notification/
        ├── main.py
        ├── notification.py
        ├── templates.json
        └── requirements.txt
```

## 🚀 **Implementation Guide**

### **Step 1: Create Module Structure**

For each Lambda function type, create a dedicated module:

```bash
# Create module directories
mkdir -p modules/lambda-s3-forwarder/src
mkdir -p modules/lambda-image-processor/src
mkdir -p modules/lambda-data-transformer/src
mkdir -p modules/lambda-notification/src
```

### **Step 2: Module Files**

Each module should have these files:

#### **main.tf** - Module Configuration
```hcl
# Example: modules/lambda-s3-forwarder/main.tf
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda-s3-forwarder.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "*.log"]
}

resource "aws_lambda_function" "s3_forwarder" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = var.function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size
  
  environment {
    variables = merge(var.environment_variables, {
      ENVIRONMENT   = var.environment
      SOURCE_BUCKET = var.source_bucket_name
      DEPLOYMENT_KEY = var.deployment_key
    })
  }
  
  tags = var.tags
}

# IAM role and policies specific to S3 forwarding
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"
  # ... assume role policy
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          data.aws_s3_bucket.source_bucket.arn,
          "${data.aws_s3_bucket.source_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}
```

#### **variables.tf** - Module Variables
```hcl
# Example: modules/lambda-s3-forwarder/variables.tf
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

# Add module-specific variables
variable "output_bucket_name" {
  description = "Output bucket for processed files (for image processor)"
  type        = string
  default     = null
}
```

#### **outputs.tf** - Module Outputs
```hcl
# Example: modules/lambda-s3-forwarder/outputs.tf
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

output "configuration" {
  description = "Lambda function configuration summary"
  value = {
    function_name = aws_lambda_function.s3_forwarder.function_name
    function_arn  = aws_lambda_function.s3_forwarder.arn
    runtime       = aws_lambda_function.s3_forwarder.runtime
    timeout       = aws_lambda_function.s3_forwarder.timeout
    memory_size   = aws_lambda_function.s3_forwarder.memory_size
    environment   = var.environment
    source_bucket = var.source_bucket_name
  }
}
```

### **Step 3: Source Code Organization**

Each module's `src/` directory contains the specific Lambda function code:

#### **S3 Forwarder Source Code**
```
modules/lambda-s3-forwarder/src/
├── main.py              # Lambda handler for S3 events
├── destinations.py      # SQS/SNS forwarding logic
├── destinations.json    # Destination configuration
├── test_destinations.py # Test script
└── requirements.txt     # Python dependencies
```

#### **Image Processor Source Code**
```
modules/lambda-image-processor/src/
├── main.py              # Lambda handler for image processing
├── image_processor.py   # Image processing logic
├── config.json          # Image processing configuration
└── requirements.txt     # Python dependencies (includes Pillow, etc.)
```

#### **Data Transformer Source Code**
```
modules/lambda-data-transformer/src/
├── main.py              # Lambda handler for data transformation
├── transformer.py       # Data transformation logic
├── schemas.json         # Data schemas
└── requirements.txt     # Python dependencies
```

### **Step 4: Main Configuration**

Use the modules in your main Terraform configuration:

```hcl
# main.tf or main-multi-modules.tf

# S3 Event Forwarder Lambdas
module "s3_forwarder_prod" {
  source = "./modules/lambda-s3-forwarder"

  function_name        = "prod-s3-event-forwarder"
  source_bucket_name   = "prod-application-bucket"
  runtime             = "python3.11"
  timeout             = 300
  memory_size         = 512
  environment         = "prod"
  
  environment_variables = {
    LOG_LEVEL = "INFO"
    MAX_RETRIES = "3"
  }
  
  tags = {
    Environment = "prod"
    FunctionType = "s3-forwarder"
  }
}

module "s3_forwarder_staging" {
  source = "./modules/lambda-s3-forwarder"

  function_name        = "staging-s3-event-forwarder"
  source_bucket_name   = "staging-application-bucket"
  runtime             = "python3.11"
  timeout             = 180
  memory_size         = 256
  environment         = "staging"
  
  environment_variables = {
    LOG_LEVEL = "DEBUG"
  }
  
  tags = {
    Environment = "staging"
    FunctionType = "s3-forwarder"
  }
}

# Image Processor Lambdas
module "image_processor_prod" {
  source = "./modules/lambda-image-processor"

  function_name        = "prod-image-processor"
  source_bucket_name   = "prod-images-bucket"
  output_bucket_name   = "prod-processed-images-bucket"
  runtime             = "python3.11"
  timeout             = 900  # 15 minutes for image processing
  memory_size         = 2048 # More memory for image processing
  environment         = "prod"
  
  environment_variables = {
    LOG_LEVEL = "INFO"
    IMAGE_QUALITY = "85"
    MAX_WIDTH = "1920"
    MAX_HEIGHT = "1080"
  }
  
  tags = {
    Environment = "prod"
    FunctionType = "image-processor"
  }
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
  
  environment_variables = {
    LOG_LEVEL = "DEBUG"
    IMAGE_QUALITY = "70"
    MAX_WIDTH = "1280"
    MAX_HEIGHT = "720"
  }
  
  tags = {
    Environment = "staging"
    FunctionType = "image-processor"
  }
}
```

## 🔧 **Benefits of Multiple Modules Approach**

### **1. Source Code Isolation**
- Each Lambda function has its own source code
- Different dependencies per function
- Independent versioning and updates

### **2. Customized IAM Permissions**
- S3 Forwarder: S3 read + SQS/SNS write
- Image Processor: S3 read/write + image processing libraries
- Data Transformer: S3 read/write + data processing libraries
- Notification Service: SNS/SES permissions

### **3. Different Resource Requirements**
- S3 Forwarder: 512MB RAM, 5 minutes timeout
- Image Processor: 2048MB RAM, 15 minutes timeout
- Data Transformer: 1024MB RAM, 10 minutes timeout

### **4. Environment-Specific Configuration**
- Production: Higher memory, longer timeouts, more logging
- Staging: Lower memory, shorter timeouts, debug logging
- Development: Minimal resources for testing

### **5. Independent Deployment**
- Deploy only specific Lambda types
- Different update cycles per function type
- Isolated testing and rollbacks

## 📋 **Deployment Examples**

### **Deploy All Lambda Functions**
```bash
cd lambda-tf
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### **Deploy Only S3 Forwarders**
```bash
# Comment out other modules in main.tf
terraform plan -target=module.s3_forwarder_prod -target=module.s3_forwarder_staging
terraform apply -target=module.s3_forwarder_prod -target=module.s3_forwarder_staging
```

### **Deploy Only Production Functions**
```bash
terraform plan -target=module.s3_forwarder_prod -target=module.image_processor_prod
terraform apply -target=module.s3_forwarder_prod -target=module.image_processor_prod
```

## 🎯 **Best Practices**

### **1. Module Naming Convention**
- Use descriptive names: `lambda-s3-forwarder`, `lambda-image-processor`
- Include function type in module name
- Use consistent naming across environments

### **2. Variable Organization**
- Common variables in root `variables.tf`
- Module-specific variables in module `variables.tf`
- Use variable validation for critical parameters

### **3. Output Management**
- Consistent output structure across modules
- Include function ARN, role ARN, and configuration summary
- Use for integration with other services

### **4. Source Code Management**
- Keep source code in module directories
- Use `.gitignore` to exclude build artifacts
- Version control source code separately if needed

### **5. Testing Strategy**
- Unit tests in each module's `src/` directory
- Integration tests for module interactions
- Separate test environments for each function type

## 🔄 **Migration from Single Module**

If you're migrating from the single shared module approach:

1. **Create new modules** for each Lambda function type
2. **Copy source code** to appropriate module directories
3. **Update main.tf** to use new modules
4. **Test each module** independently
5. **Deploy incrementally** to avoid downtime

## 📊 **Monitoring and Logging**

Each module creates its own:
- CloudWatch Log Groups
- CloudWatch Alarms
- CloudWatch Dashboards
- IAM Roles and Policies

This provides:
- Isolated monitoring per function type
- Different alert thresholds per function
- Separate log retention policies
- Function-specific dashboards

## 🚨 **Troubleshooting**

### **Common Issues**

1. **Module Source Path Issues**
   ```bash
   # Ensure module paths are correct
   ls -la modules/lambda-s3-forwarder/
   ```

2. **Source Code Packaging Issues**
   ```bash
   # Check ZIP file creation
   ls -la modules/lambda-s3-forwarder/*.zip
   ```

3. **IAM Permission Issues**
   ```bash
   # Verify IAM policies are correct
   terraform plan -target=module.s3_forwarder_prod
   ```

4. **Environment Variable Issues**
   ```bash
   # Check environment variables
   aws lambda get-function-configuration --function-name prod-s3-event-forwarder
   ```

This multi-module approach provides maximum flexibility and maintainability for deploying multiple Lambda functions with different source code and requirements. 