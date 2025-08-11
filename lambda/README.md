# S3 Event Forwarder Lambda Function

This Lambda function acts as a forwarder for S3 events to various destinations including SQS queues and SNS topics.

## 🎯 Overview

The S3 Event Forwarder Lambda function:
- **Receives** S3 events from CloudWatch Events or EventBridge
- **Extracts** event details (bucket name, object key, event type, etc.)
- **Forwards** events to multiple configured destinations
- **Supports** SQS queues and SNS topics
- **Handles** multiple destinations of each type
- **Provides** comprehensive logging and error handling

## 🏗️ Architecture

The S3 Event Forwarder is built with a modular, simplified architecture:

```
forwarder-lambda/
├── main.py                 # Main Lambda handler
├── config.py              # Configuration management
├── destinations.py        # AWS destination forwarding
├── cloudformation.yml     # Infrastructure as Code
├── deploy.sh             # Deployment script
├── config.json           # Sample configuration
├── requirements.txt      # Python dependencies
├── test_lambda.py        # Local testing
└── README.md            # Documentation
```

### **Core Components**

1. **`main.py`** - Main Lambda handler
   - Extracts S3 events from various formats
   - Forwards events to configured destinations
   - Handles errors and logging

2. **`config.py`** - Configuration management
   - Loads config from environment variables, files, or defaults
   - Ensures required structure with empty arrays
   - Simple fallback mechanism

3. **`destinations.py`** - AWS destination forwarding
   - `DestinationForwarder` class for SQS and SNS
   - Message preparation and attribute handling
   - Error handling and logging

4. **`cloudformation.yml`** - Infrastructure as Code
   - Lambda function with S3 trigger
   - IAM roles and permissions
   - CloudWatch monitoring and alarms
   - S3 bucket notification configuration

## 📁 File Structure

```
forwarder-lambda/
├── main.py                 # Main Lambda handler
├── config.py              # Configuration management
├── destinations.py         # Destination forwarding logic
├── cloudformation.yml     # Infrastructure as Code
├── deploy.sh             # Deployment script
├── config.json            # Sample configuration file
├── requirements.txt       # Python dependencies
├── test_lambda.py        # Local testing
└── README.md             # This documentation
```

## 🚀 Features

### **Event Processing**
- ✅ Handles multiple S3 event formats
- ✅ Extracts relevant event information
- ✅ Validates event structure
- ✅ Comprehensive error handling

### **Destination Support**
- ✅ **SQS Queues:** Multiple queues with message attributes
- ✅ **SNS Topics:** Multiple topics with structured messages
- ✅ **Configurable:** Easy to add new destination types
- ✅ **Enabled/Disabled:** Per-destination configuration

### **Configuration Management**
- ✅ **Environment Variables:** Priority configuration
- ✅ **Config Files:** JSON-based configuration
- ✅ **Default Config:** Fallback configuration
- ✅ **Validation:** Configuration structure validation

### **Monitoring & Logging**
- ✅ **Detailed Logging:** Comprehensive event processing logs
- ✅ **Error Tracking:** Failed destination tracking
- ✅ **Success Metrics:** Successful forwarding metrics
- ✅ **Debug Information:** Detailed debugging information

## 🚀 Deployment

### **Prerequisites**

1. **AWS CLI** installed and configured
2. **Python 3.9+** for local development
3. **SQS Queues** and **SNS Topics** created (optional)
4. **S3 Bucket** to monitor for events
5. **IAM Permissions** for Lambda execution

### **Quick Deployment**

```bash
# Deploy with default settings
./deploy.sh -b my-s3-bucket

# Deploy with specific prefix and suffix
./deploy.sh -b my-s3-bucket -p "logs/" -s ".json"

# Deploy with specific events
./deploy.sh -b my-s3-bucket -e "s3:ObjectCreated:Put,s3:ObjectCreated:Post"

# Deploy to different region and environment
./deploy.sh -b my-s3-bucket -r us-west-2 -n staging
```

### **Deployment Options**

| Option | Description | Default |
|--------|-------------|---------|
| `-b, --bucket-name` | S3 bucket name to monitor | Required |
| `-p, --prefix` | S3 object key prefix filter | None |
| `-s, --suffix` | S3 object key suffix filter | None |
| `-e, --events` | S3 events to trigger Lambda | `s3:ObjectCreated:*,s3:ObjectRemoved:*` |
| `-r, --region` | AWS region | `us-east-1` |
| `-n, --environment` | Environment name | `prod` |

### **S3 Trigger Configuration**

The Lambda function is automatically configured with S3 triggers based on your deployment parameters:

#### **Event Types**
- `s3:ObjectCreated:*` - All object creation events
- `s3:ObjectCreated:Put` - Object PUT events
- `s3:ObjectCreated:Post` - Object POST events
- `s3:ObjectCreated:Copy` - Object COPY events
- `s3:ObjectRemoved:*` - All object removal events
- `s3:ObjectRemoved:Delete` - Object DELETE events

#### **Filtering Options**
- **Prefix Filter:** Only process objects with specific key prefixes
- **Suffix Filter:** Only process objects with specific key suffixes
- **Combined Filter:** Use both prefix and suffix for precise filtering

#### **Example Configurations**

```bash
# Monitor all events in the bucket
./deploy.sh -b my-bucket

# Monitor only JSON files in logs/ directory
./deploy.sh -b my-bucket -p "logs/" -s ".json"

# Monitor only PUT events for images
./deploy.sh -b my-bucket -p "images/" -s ".jpg" -e "s3:ObjectCreated:Put"

# Monitor multiple event types
./deploy.sh -b my-bucket -e "s3:ObjectCreated:Put,s3:ObjectCreated:Post,s3:ObjectRemoved:Delete"
```

## 🔧 Configuration

### **Configuration Sources (Priority Order)**

1. **Environment Variables**
2. **Config Files**
3. **Default Configuration**

### **Environment Variables**

```bash
# Full configuration
export S3_FORWARDER_CONFIG='{"sqs_queues":[...],"sns_topics":[...]}'

# Individual configurations
export S3_FORWARDER_SQS_QUEUES='[{"name":"queue1","url":"...","arn":"..."}]'
export S3_FORWARDER_SNS_TOPICS='[{"name":"topic1","arn":"..."}]'

# Empty arrays (no destinations)
export S3_FORWARDER_SQS_QUEUES='[]'
export S3_FORWARDER_SNS_TOPICS='[]'
```

### **Config File Structure**

```json
{
  "sqs_queues": [
    {
      "name": "s3-events-processing-queue",
      "url": "https://sqs.us-east-1.amazonaws.com/123456789012/s3-events-processing-queue",
      "arn": "arn:aws:sqs:us-east-1:123456789012:s3-events-processing-queue",
      "enabled": true
    }
  ],
  "sns_topics": [
    {
      "name": "s3-events-notifications",
      "arn": "arn:aws:sns:us-east-1:123456789012:s3-events-notifications",
      "enabled": true
    }
  ]
}
```

### **Empty Arrays Support**

The Lambda function supports empty arrays for both SQS queues and SNS topics:

- **Disable all SQS forwarding:** Set `sqs_queues` to `[]`
- **Disable all SNS forwarding:** Set `sns_topics` to `[]`
- **Disable all forwarding:** Set both arrays to `[]`

#### **Example: Empty Configuration**

```json
{
  "sqs_queues": [],
  "sns_topics": []
}
```

#### **Example: SQS Only**

```json
{
  "sqs_queues": [
    {
      "name": "s3-events-processing-queue",
      "url": "https://sqs.us-east-1.amazonaws.com/123456789012/s3-events-processing-queue",
      "arn": "arn:aws:sqs:us-east-1:123456789012:s3-events-processing-queue",
      "enabled": true
    }
  ],
  "sns_topics": []
}
```

#### **Example: SNS Only**

```json
{
  "sqs_queues": [],
  "sns_topics": [
    {
      "name": "s3-events-notifications",
      "arn": "arn:aws:sns:us-east-1:123456789012:s3-events-notifications",
      "enabled": true
    }
  ]
}
```

### **Enabled Field Support**

The Lambda function supports individual destination enable/disable using the `enabled` field:

- **Enable destination:** Set `enabled: true` (default if not specified)
- **Disable destination:** Set `enabled: false`
- **Default behavior:** Destinations are enabled by default if `enabled` field is not specified

#### **Example: Mixed Enabled/Disabled Destinations**

```json
{
  "sqs_queues": [
    {
      "name": "processing-queue",
      "url": "https://sqs.us-east-1.amazonaws.com/123456789012/processing-queue",
      "arn": "arn:aws:sqs:us-east-1:123456789012:processing-queue",
      "enabled": true
    },
    {
      "name": "backup-queue",
      "url": "https://sqs.us-east-1.amazonaws.com/123456789012/backup-queue",
      "arn": "arn:aws:sqs:us-east-1:123456789012:backup-queue",
      "enabled": false
    },
    {
      "name": "analytics-queue",
      "url": "https://sqs.us-east-1.amazonaws.com/123456789012/analytics-queue",
      "arn": "arn:aws:sqs:us-east-1:123456789012:analytics-queue"
      // enabled field not specified - defaults to true
    }
  ],
  "sns_topics": [
    {
      "name": "notifications",
      "arn": "arn:aws:sns:us-east-1:123456789012:notifications",
      "enabled": true
    },
    {
      "name": "alerts",
      "arn": "arn:aws:sns:us-east-1:123456789012:alerts",
      "enabled": false
    }
  ]
}
```

#### **Benefits of Enabled Field**

1. **Granular Control:** Enable/disable individual destinations without removing them from config
2. **Temporary Disabling:** Quickly disable destinations for maintenance or testing
3. **Environment Management:** Use same config across environments with different enabled states
4. **Rollback Capability:** Easily re-enable disabled destinations
5. **Configuration Management:** Keep all destinations in config for documentation purposes

### **Configuration Validation**

The function automatically ensures the required structure:

- **Missing arrays:** Automatically added as empty arrays
- **Invalid types:** Reset to empty arrays with warning
- **Partial configs:** Missing arrays are added as empty arrays
- **Enabled field:** Defaults to `true` if not specified

## 📊 Event Structure

### **Input Event (S3 Event)**

```json
{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3",
      "awsRegion": "us-east-1",
      "eventTime": "2024-12-01T10:00:00.000Z",
      "eventName": "ObjectCreated:Put",
      "s3": {
        "bucket": {
          "name": "my-bucket"
        },
        "object": {
          "key": "path/to/file.txt"
        }
      }
    }
  ]
}
```

### **Output Message (SQS)**

```json
{
  "event_type": "s3_event",
  "event_name": "ObjectCreated:Put",
  "bucket_name": "my-bucket",
  "object_key": "path/to/file.txt",
  "event_time": "2024-12-01T10:00:00.000Z",
  "event_source": "aws:s3",
  "aws_region": "us-east-1",
  "destination_type": "sqs",
  "destination_name": "s3-events-processing-queue",
  "destination_url": "https://sqs.us-east-1.amazonaws.com/123456789012/s3-events-processing-queue",
  "raw_event": {...},
  "timestamp": "2024-12-01T10:00:00.000Z"
}
```

### **Output Message (SNS)**

```json
{
  "event_type": "s3_event",
  "event_name": "ObjectCreated:Put",
  "bucket_name": "my-bucket",
  "object_key": "path/to/file.txt",
  "event_time": "2024-12-01T10:00:00.000Z",
  "event_source": "aws:s3",
  "aws_region": "us-east-1",
  "destination_type": "sns",
  "destination_name": "s3-events-notifications",
  "destination_arn": "arn:aws:sns:us-east-1:123456789012:s3-events-notifications",
  "raw_event": {...},
  "timestamp": "2024-12-01T10:00:00.000Z"
}
```

## 🔍 Monitoring

### **CloudWatch Alarms**

The deployment automatically creates CloudWatch alarms:

1. **Error Alarm:** Triggers when Lambda function encounters errors
2. **Duration Alarm:** Triggers when Lambda function takes too long to execute

### **CloudWatch Logs**

All Lambda function logs are automatically sent to CloudWatch Logs:
- Log Group: `/aws/lambda/{environment}-s3-event-forwarder`
- Retention: 30 days

### **Testing**

```bash
# Test the deployment locally
python test_lambda.py

# Test with AWS CLI
aws lambda invoke \
    --function-name prod-s3-event-forwarder \
    --payload '{"Records":[{"eventSource":"aws:s3","eventName":"ObjectCreated:Put","s3":{"bucket":{"name":"test-bucket"},"object":{"key":"test.txt"}}}]}' \
    response.json
```

## 🛠️ Troubleshooting

### **Common Issues**

1. **S3 Bucket Not Found**
   - Ensure the S3 bucket exists and is accessible
   - Check AWS credentials and permissions

2. **Lambda Function Not Triggered**
   - Verify S3 bucket notification configuration
   - Check Lambda function permissions
   - Review CloudWatch logs for errors

3. **Destination Forwarding Failed**
   - Verify SQS queue and SNS topic ARNs
   - Check IAM permissions for SQS and SNS
   - Review destination configuration

### **Log Analysis**

```bash
# View Lambda function logs
aws logs tail /aws/lambda/prod-s3-event-forwarder --follow

# View specific log stream
aws logs describe-log-streams \
    --log-group-name /aws/lambda/prod-s3-event-forwarder \
    --order-by LastEventTime \
    --descending
```

## 🔄 Updates

### **Updating Configuration**

```bash
# Update environment variables
aws lambda update-function-configuration \
    --function-name prod-s3-event-forwarder \
    --environment Variables='{S3_FORWARDER_CONFIG="{\"sqs_queues\":[],\"sns_topics\":[]}"}'

# Update function code
./deploy.sh -b my-bucket
```

### **Rollback**

```bash
# Rollback to previous version
aws cloudformation rollback-stack \
    --stack-name s3-event-forwarder \
    --region us-east-1
```

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details. 