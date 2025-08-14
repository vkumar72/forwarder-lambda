# S3 Event Forwarder Lambda - Terraform

This Terraform configuration creates a Lambda function that forwards S3 events to multiple destinations (SQS and SNS) based on a JSON configuration file.

## Features

- **Multiple Lambda Deployments**: Deploy multiple Lambda functions with different configurations
- **Flexible Resource Configuration**: Different memory, timeout, and runtime settings per deployment
- **S3 Event Filtering**: Configure prefix/suffix filters for S3 events
- **Environment Variables**: Custom environment variables per deployment
- **Enhanced Monitoring**: CloudWatch alarms, metrics, and dashboards per deployment
- **IAM Role**: Proper permissions for S3, SQS, SNS, and CloudWatch
- **S3 Bucket Notification**: Automatically configures S3 bucket to trigger Lambda
- **Multiple Destinations**: Forward events to SQS queues and SNS topics
- **Configurable**: JSON file to enable/disable destinations
- **Jenkins Pipeline**: Automated deployment via Jenkins
- **State Bucket Management**: Optional automatic creation of S3 state bucket with security best practices
- **State Locking**: Optional DynamoDB-based state locking for team collaboration
- **VPC Support**: Run Lambda functions within VPC for enhanced security and network isolation
- **Backward Compatibility**: Support for legacy single deployment configuration

## Architecture

```
S3 Bucket → Lambda Function → SQS Queues
                    ↓
                SNS Topics
```

## Prerequisites

1. **AWS Account**: With appropriate permissions
2. **S3 Bucket**: Pre-existing bucket to monitor
3. **Terraform State Bucket**: S3 bucket for storing Terraform state (can be created automatically)
4. **Jenkins**: For automated deployment (optional)
5. **Terraform**: Version 1.0 or higher

## Directory Structure

```
lambda-tf/
├── main.tf                 # Main Terraform configuration
├── state-bucket.tf         # S3 state bucket configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example variable values
├── terraform-ops.sh        # Terraform operations script
├── init-state-bucket.sh    # State bucket initialization script
├── Jenkinsfile             # Jenkins pipeline
├── README.md               # This file
└── modules/
    └── lambda/
        ├── main.tf         # Lambda module configuration
        ├── variables.tf    # Lambda module variables
        ├── outputs.tf      # Lambda module outputs
        └── src/            # Lambda function source code
            ├── main.py     # Lambda handler
            ├── destinations.py # Destination management
            ├── destinations.json # Destination configuration
            └── requirements.txt # Python dependencies
```

## Configuration

### 1. Terraform Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` and update the values. You can choose between multi-deployment and legacy single deployment approaches:

#### Multi-Deployment Configuration (Recommended)
```hcl
aws_region = "us-east-1"
terraform_state_bucket = "your-terraform-state-bucket"
create_state_bucket = false
enable_state_locking = false

# Global settings for all deployments
global_settings = {
  enable_state_bucket_creation = false
  enable_state_locking         = false
  default_runtime              = "python3.11"
  default_timeout              = 300
  default_memory_size          = 512
  default_log_retention        = 30
  default_permission_boundary_arn = "arn:aws:iam::123456789012:policy/my-perm-boundary"  # Optional: Global permission boundary
  default_tags = {
    Environment = "prod"
    Project     = "s3-event-forwarder"
    ManagedBy   = "terraform"
  }
}

# Multiple Lambda deployments
lambda_deployments = {
  "prod-main" = {
    function_name        = "prod-s3-event-forwarder-main"
    source_bucket_name   = "prod-main-application-bucket"
    runtime             = "python3.11"
    timeout             = 300
    memory_size         = 512
    environment         = "prod"
    permission_boundary_arn = "arn:aws:iam::123456789012:policy/prod-perm-boundary"  # Production-specific permission boundary
    s3_prefix           = "uploads/"
    s3_suffix           = ".json"
    environment_variables = {
      LOG_LEVEL = "INFO"
      MAX_RETRIES = "3"
    }
  }
  
  "staging-test" = {
    function_name        = "staging-s3-event-forwarder-test"
    source_bucket_name   = "staging-test-bucket"
    timeout             = 180
    memory_size         = 256
    environment         = "staging"
    s3_prefix           = "test-data/"
    environment_variables = {
      LOG_LEVEL = "DEBUG"
    }
  }
}
```

#### Legacy Single Deployment Configuration
```hcl
aws_region = "us-east-1"
terraform_state_bucket = "your-terraform-state-bucket"
create_state_bucket = false
enable_state_locking = false
source_bucket_name = "your-source-s3-bucket"
function_name = "s3-event-forwarder"
environment = "prod"
```

### 2. Permission Boundary Configuration

Permission boundaries help enforce security policies by limiting the maximum permissions that can be granted to IAM roles. You can configure permission boundaries at multiple levels:

#### **Global Permission Boundary**
Set a default permission boundary for all deployments:
```hcl
global_settings = {
  default_permission_boundary_arn = "arn:aws:iam::123456789012:policy/my-perm-boundary"
}
```

#### **Deployment-Specific Permission Boundary**
Override the global setting for specific deployments:
```hcl
lambda_deployments = {
  "prod-main" = {
    function_name = "prod-s3-event-forwarder-main"
    source_bucket_name = "prod-main-application-bucket"
    permission_boundary_arn = "arn:aws:iam::123456789012:policy/prod-perm-boundary"
    # ... other configuration
  }
  
  "dev-feature" = {
    function_name = "dev-s3-event-forwarder-feature"
    source_bucket_name = "dev-feature-bucket"
    permission_boundary_arn = "arn:aws:iam::123456789012:policy/dev-perm-boundary"
    # ... other configuration
  }
}
```

### 3. VPC Configuration

Lambda functions can be configured to run within a VPC for enhanced security and network isolation. This is useful when Lambda functions need to access private resources like RDS, ElastiCache, or other VPC resources.

#### **Global VPC Configuration**
Set VPC configuration for all deployments:
```hcl
global_settings = {
  # ... other settings ...
  
  default_vpc_config = {
    vpc_id = "vpc-12345678"
    subnet_ids = [
      "subnet-12345678",  # Private subnet 1
      "subnet-87654321"   # Private subnet 2
    ]
    security_group_ids = [
      "sg-12345678"  # Lambda security group
    ]
  }
}
```

#### **Deployment-Specific VPC Configuration**
Override VPC configuration for specific deployments:
```hcl
lambda_deployments = {
  "prod-vpc" = {
    function_name = "prod-vpc-forwarder"
    source_bucket_name = "prod-bucket"
    environment = "prod"
    # Uses global VPC configuration
  }
  
  "staging-no-vpc" = {
    function_name = "staging-forwarder"
    source_bucket_name = "staging-bucket"
    environment = "staging"
    vpc_config = null  # Override: no VPC
  }
  
  "prod-critical" = {
    function_name = "prod-critical-forwarder"
    source_bucket_name = "prod-critical-bucket"
    environment = "prod"
    vpc_config = {
      vpc_id = "vpc-87654321"  # Different VPC
      subnet_ids = [
        "subnet-87654321",
        "subnet-12345678"
      ]
      security_group_ids = [
        "sg-87654321",
        "sg-12345678"
      ]
    }
  }
}
```

#### **VPC Requirements**
When configuring Lambda functions to run in VPC, ensure you have:

1. **Private Subnets**: Lambda functions must be placed in private subnets
2. **NAT Gateway**: Required for internet access (AWS SDK calls, external APIs)
3. **Security Groups**: Configured with appropriate outbound rules
4. **VPC Endpoints**: Optional, for enhanced security and performance

For detailed VPC setup instructions, see [VPC_CONFIGURATION.md](VPC_CONFIGURATION.md).
    # ... other configuration
  }
}
```

#### **No Permission Boundary**
To disable permission boundaries for a deployment, set to `null`:
```hcl
permission_boundary_arn = null
```

### 3. State Bucket Setup

You have two options for setting up the Terraform state bucket:

#### Option A: Use Existing Bucket (Recommended for Production)
1. Create the S3 bucket manually or use the provided script:
   ```bash
   ./init-state-bucket.sh your-terraform-state-bucket us-east-1 true
   ```
2. Set `create_state_bucket = false` in your `terraform.tfvars`

#### Option B: Create Bucket Automatically
1. Set `create_state_bucket = true` in your `terraform.tfvars`
2. Optionally set `enable_state_locking = true` for DynamoDB state locking
3. Terraform will create the bucket with proper security settings

### 4. Terraform Operations Script

The `terraform-ops.sh` script provides a standardized way to run Terraform operations with proper error handling and logging. It includes:

- **Validation**: Checks Terraform configuration syntax and formatting
- **Colored Output**: Clear, colored logging for better visibility
- **Error Handling**: Proper error handling and exit codes
- **Parameter Validation**: Validates required parameters for each action
- **Flexible Options**: Supports various Terraform operations and options

#### Script Usage:
```bash
./terraform-ops.sh <action> [options]

Actions:
  init     - Initialize Terraform
  plan     - Create Terraform plan
  apply    - Apply Terraform configuration
  destroy  - Destroy Terraform resources
  output   - Show Terraform outputs
  validate - Validate Terraform configuration
  fmt      - Check Terraform formatting

Options:
  --bucket <bucket-name>     - S3 bucket for state storage
  --key <state-key>          - State file key
  --region <region>          - AWS region
  --vars <var-file>          - Variables file (terraform.tfvars)
  --auto-approve             - Auto approve for apply/destroy
  --plan-file <file>         - Plan file for apply
```

### 5. Multi-Deployment Features

The new multi-deployment configuration supports the following features per deployment:

#### Resource Configuration
- **Runtime**: Different Python runtimes per deployment
- **Memory**: Custom memory allocation (128MB to 10240MB)
- **Timeout**: Custom timeout settings (1-900 seconds)
- **Concurrency**: Reserved concurrency limits
- **Description**: Custom function descriptions

#### S3 Event Configuration
- **Event Types**: Customize which S3 events trigger the Lambda
- **Prefix Filtering**: Only process objects with specific prefixes
- **Suffix Filtering**: Only process objects with specific suffixes
- **Multiple Events**: Support for creation, deletion, and restore events

#### Environment Variables
- **Custom Variables**: Deploy-specific environment variables
- **Log Levels**: Different logging levels per deployment
- **Feature Flags**: Enable/disable features per deployment
- **Configuration**: Custom retry limits, batch sizes, etc.

#### IAM Configuration
- **Permission Boundaries**: Set permission boundaries for IAM roles
- **Global Defaults**: Configure default permission boundaries for all deployments
- **Deployment-Specific**: Override permission boundaries per deployment
- **Security Compliance**: Ensure IAM roles follow organizational security policies

#### Monitoring Configuration
- **CloudWatch Alarms**: Custom error and duration thresholds
- **Log Retention**: Different retention periods per deployment
- **Metrics**: Enable/disable CloudWatch metrics
- **Dashboards**: Automatic CloudWatch dashboard creation

### 6. Destinations Configuration

Edit `modules/lambda/src/destinations.json` to configure your destinations. The Lambda function will only send messages to destinations marked as `enabled: true`.

#### **Configuration Format**
```json
{
  "destinations": [
    {
      "name": "processing-queue",
      "type": "sqs",
      "arn": "https://sqs.us-east-1.amazonaws.com/123456789012/processing-queue",
      "enabled": true,
      "description": "SQS queue for processing S3 events"
    },
    {
      "name": "notification-topic",
      "type": "sns",
      "arn": "arn:aws:sns:us-east-1:123456789012:notification-topic",
      "enabled": true,
      "description": "SNS topic for S3 event notifications"
    },
    {
      "name": "backup-queue",
      "type": "sqs",
      "arn": "https://sqs.us-east-1.amazonaws.com/123456789012/backup-queue",
      "enabled": false,
      "description": "SQS queue for backup processing (disabled)"
    }
  ]
}
```

#### **Destination Types**

**SQS Queues**:
- Use Queue URL format: `https://sqs.region.amazonaws.com/account-id/queue-name`
- Supports message batching and attributes
- Messages include S3 event details and metadata

**SNS Topics**:
- Use Topic ARN format: `arn:aws:sns:region:account-id:topic-name`
- Supports message subjects and attributes
- Messages include S3 event details and metadata

#### **Enable/Disable Destinations**
- Set `"enabled": true` to allow the Lambda to send messages
- Set `"enabled": false` to disable message sending (useful for testing)
- Only enabled destinations will receive S3 events
- Permissions are automatically managed based on enabled status

#### **Message Format**
All messages include:
- **Source**: `s3-event-forwarder`
- **Timestamp**: Event processing time
- **Event Details**: Complete S3 event information
- **Metadata**: Environment, bucket, and deployment information

#### **Destination Verification**
The Lambda function includes built-in destination verification:

- **Automatic Logging**: Every Lambda invocation logs currently enabled destinations
- **Verification Format**: Clear, formatted output showing destination names, types, ARNs, and descriptions
- **CloudWatch Integration**: Verification information appears in CloudWatch logs for easy monitoring
- **Test Script**: Use `test_destinations.py` to verify destinations without processing events

**Example CloudWatch Log Output**:
```
=== DESTINATION VERIFICATION ===
Currently Enabled Destinations:
  1. processing-queue (SQS)
     ARN: https://sqs.us-east-1.amazonaws.com/123456789012/processing-queue
     Description: SQS queue for processing S3 events

  2. notification-topic (SNS)
     ARN: arn:aws:sns:us-east-1:123456789012:notification-topic
     Description: SNS topic for S3 event notifications

Total Enabled Destinations: 2
=== END DESTINATION VERIFICATION ===
```

## Deployment

### Manual Deployment

#### Option A: Using Terraform Directly
1. **Initialize Terraform**:
   ```bash
   cd lambda-tf
   terraform init
   ```

2. **Plan the deployment**:
   ```bash
   terraform plan -var-file="terraform.tfvars"
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

#### Option B: Using the Terraform Operations Script (Recommended)
1. **Make script executable and validate**:
   ```bash
   cd lambda-tf
   chmod +x terraform-ops.sh
   ./terraform-ops.sh validate
   ```

2. **Initialize Terraform**:
   ```bash
   ./terraform-ops.sh init \
     --bucket your-terraform-state-bucket \
     --key lambda-s3-forwarder/prod/terraform.tfstate \
     --region us-east-1
   ```

3. **Plan the deployment**:
   ```bash
   ./terraform-ops.sh plan --vars terraform.tfvars
   ```

4. **Apply the configuration**:
   ```bash
   ./terraform-ops.sh apply --plan-file tfplan --auto-approve
   ```

5. **View outputs**:
   ```bash
   ./terraform-ops.sh output
   ```

### Jenkins Pipeline Deployment

The Jenkins pipeline uses the `terraform-ops.sh` script for all Terraform operations, providing:

- **Consistent Execution**: All Terraform commands go through the same script
- **Better Logging**: Colored output and structured logging
- **Error Handling**: Proper error handling and validation
- **Validation**: Automatic validation and formatting checks
- **Multi-Deployment Support**: Support for both single and multiple Lambda deployments

1. **Configure Jenkins Pipeline**:
   - Set up a Jenkins job pointing to this repository
   - Configure the pipeline parameters:
     - `ENVIRONMENT`: Environment name (dev/staging/prod)
     - `TERRAFORM_STATE_BUCKET`: S3 bucket for Terraform state
     - `CREATE_STATE_BUCKET`: Create state bucket automatically
     - `ENABLE_STATE_LOCKING`: Enable DynamoDB state locking
     - `USE_MULTI_DEPLOYMENT`: Use multi-deployment configuration (default: true)
     - `LAMBDA_DEPLOYMENTS_JSON`: JSON configuration for deployments (optional)
     - `ACTION`: Terraform action (plan/apply/destroy)
     
     **Legacy Parameters (for backward compatibility)**:
     - `SOURCE_BUCKET_NAME`: S3 bucket to monitor (legacy)
     - `FUNCTION_NAME`: Lambda function name (legacy)

2. **Pipeline Stages**:
   - **Checkout**: Clone the repository
   - **Setup Environment**: Install Terraform if needed
   - **Terraform Validation**: Validate configuration and formatting
   - **Terraform Init**: Initialize backend
   - **Terraform Plan**: Create execution plan
   - **Terraform Apply**: Apply configuration
   - **Output Results**: Display outputs

3. **Multi-Deployment Usage**:
   - Set `USE_MULTI_DEPLOYMENT = true`
   - Configure `terraform.tfvars` with your deployment configurations
   - Pipeline will use the multi-deployment configuration automatically

4. **Legacy Usage**:
   - Set `USE_MULTI_DEPLOYMENT = false`
   - Provide `SOURCE_BUCKET_NAME` and `FUNCTION_NAME` parameters
   - Pipeline will create a single deployment configuration

5. **Run the Pipeline**:
   - Select the desired action
   - Provide the required parameters
   - Monitor the pipeline execution

## Lambda Function Details

### Handler Function

The Lambda function (`main.py`) processes S3 events and forwards them to configured destinations:

- **Input**: S3 event records
- **Processing**: Extracts event details and forwards to enabled destinations
- **Output**: Success/failure status

### Destination Management

The `destinations.py` module handles:

- Loading destination configuration from JSON file
- Forwarding events to SQS queues
- Publishing events to SNS topics
- Error handling and logging
- Destination verification and validation
- Logging enabled destinations for verification

### Supported Event Types

- `s3:ObjectCreated:*` - Object creation events
- `s3:ObjectRemoved:*` - Object deletion events

## Monitoring and Logging

### Multi-Deployment Outputs

After deployment, you can view comprehensive information about all deployments:

```bash
# View all deployments
terraform output lambda_deployments

# View deployment summary
terraform output deployment_summary

# View CloudWatch alarms
terraform output cloudwatch_alarms
```

### CloudWatch Logs

- **Log Group**: `/aws/lambda/{function-name}` (per deployment)
- **Retention**: Configurable per deployment (7-365 days)
- **Log Level**: Configurable per deployment (DEBUG, INFO, ERROR)

### CloudWatch Metrics

- **Lambda Invocations**: Per deployment
- **Lambda Errors**: Per deployment with custom thresholds
- **Lambda Duration**: Per deployment with custom thresholds
- **Lambda Throttles**: Per deployment

### CloudWatch Alarms

- **Error Alarms**: Custom error thresholds per deployment
- **Duration Alarms**: Custom duration thresholds per deployment
- **Conditional**: Can be enabled/disabled per deployment

### CloudWatch Dashboards

- **Automatic Creation**: Dashboards created for each deployment
- **Metrics Visualization**: Invocations, errors, duration, throttles
- **Real-time Monitoring**: 5-minute update intervals

## Security

### IAM Permissions

The Lambda function has comprehensive permissions for secure operation:

#### **S3 Permissions**
- **Read Access**: `s3:GetObject`, `s3:GetObjectVersion`, `s3:GetObjectAcl` for source bucket
- **Notification Management**: `s3:GetBucketNotification`, `s3:PutBucketNotification` for bucket configuration
- **Configuration Access**: Read access to `destinations.json` file

#### **SQS Permissions** (for enabled destinations only)
- **Message Operations**: `sqs:SendMessage`, `sqs:SendMessageBatch`
- **Queue Management**: `sqs:GetQueueUrl`, `sqs:GetQueueAttributes`
- **Conditional Access**: Only for destinations marked as `enabled: true`

#### **SNS Permissions** (for enabled destinations only)
- **Publishing**: `sns:Publish` for sending notifications
- **Topic Management**: `sns:GetTopicAttributes`
- **Conditional Access**: Only for destinations marked as `enabled: true`

#### **CloudWatch Permissions**
- **Logging**: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
- **Metrics**: `cloudwatch:PutMetricData`, `cloudwatch:GetMetricData`
- **Alarms**: Access to CloudWatch alarms and dashboards

#### **Lambda Permissions**
- **Self-Description**: `lambda:GetFunction`, `lambda:GetFunctionConfiguration`
- **Monitoring**: Access to function metrics and configuration

#### **KMS Permissions** (for encrypted destinations)
- **Decryption**: `kms:Decrypt` for encrypted SQS/SNS messages
- **Key Generation**: `kms:GenerateDataKey` for encrypted communications

#### **EventBridge Permissions**
- **Event Publishing**: `events:PutEvents` for additional notification capabilities

### Best Practices

- Use least privilege principle
- Enable CloudTrail for audit logging
- Regularly rotate access keys
- Monitor Lambda function metrics

## Troubleshooting

### Common Issues

1. **S3 Bucket Not Found**:
   - Verify the bucket name in `terraform.tfvars`
   - Ensure the bucket exists in the specified region

2. **Lambda Permission Denied**:
   - Check IAM role permissions
   - Verify S3 bucket notification configuration

3. **Destination Not Receiving Events**:
   - Check if destination is enabled in `destinations.json`
   - Verify destination ARN is correct
   - Check destination permissions

### Debugging

1. **Check CloudWatch Logs**:
   ```bash
   aws logs tail /aws/lambda/s3-event-forwarder --follow
   ```

2. **Test Lambda Function**:
   ```bash
   aws lambda invoke --function-name s3-event-forwarder test-event.json
   ```

3. **Verify S3 Notification**:
   ```bash
   aws s3api get-bucket-notification-configuration --bucket your-bucket-name
   ```

4. **Verify Destinations Configuration**:
   ```bash
   # Run the test script to verify destinations
   cd lambda-tf/modules/lambda/src
   python test_destinations.py
   ```

5. **Check Enabled Destinations in Logs**:
   Look for the "DESTINATION VERIFICATION" section in CloudWatch logs to see which destinations are currently enabled and will receive events.

## Cleanup

To destroy all resources:

```bash
terraform destroy -var-file="terraform.tfvars"
```

Or use Jenkins pipeline with `ACTION=destroy`.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License. 