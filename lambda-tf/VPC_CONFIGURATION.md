# VPC Configuration for Lambda Functions

This document explains how to configure Lambda functions to run within a VPC (Virtual Private Cloud) using the Terraform configuration provided.

## Table of Contents

1. [Overview](#overview)
2. [VPC Configuration Options](#vpc-configuration-options)
3. [Prerequisites](#prerequisites)
4. [Configuration Examples](#configuration-examples)
5. [Security Considerations](#security-considerations)
6. [Network Requirements](#network-requirements)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## Overview

Running Lambda functions in a VPC provides several benefits:

- **Network Isolation**: Lambda functions can access private resources within your VPC
- **Security**: Enhanced security through security groups and network ACLs
- **Compliance**: Meet compliance requirements that mandate private network access
- **Resource Access**: Access to RDS, ElastiCache, and other VPC resources

## VPC Configuration Options

### 1. Global VPC Configuration

Set VPC configuration at the global level for all Lambda functions:

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

### 2. Deployment-Specific VPC Configuration

Override VPC configuration for specific deployments:

```hcl
lambda_deployments = {
  "prod-critical" = {
    # ... other settings ...
    
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

### 3. No VPC Configuration

Run Lambda functions outside VPC (default AWS Lambda behavior):

```hcl
# Global level
global_settings = {
  default_vpc_config = null
}

# Or deployment-specific
lambda_deployments = {
  "staging-test" = {
    # ... other settings ...
    vpc_config = null
  }
}
```

## Prerequisites

### 1. VPC Setup

Ensure you have a VPC with the following components:

```hcl
# Example VPC setup (not included in this module)
resource "aws_vpc" "lambda_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "lambda-vpc"
  }
}

# Private subnets (required for Lambda)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "private-subnet-${count.index + 1}"
    Type = "private"
  }
}

# Security group for Lambda
resource "aws_security_group" "lambda" {
  name        = "lambda-security-group"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.lambda_vpc.id
  
  # Outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "lambda-security-group"
  }
}
```

### 2. NAT Gateway (Required for Internet Access)

Lambda functions in private subnets need a NAT Gateway to access the internet:

```hcl
# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.lambda_vpc.id
  
  tags = {
    Name = "main-igw"
  }
}

# Public subnets for NAT Gateway
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-${count.index + 1}"
    Type = "public"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = 2
  vpc   = true
  
  tags = {
    Name = "nat-eip-${count.index + 1}"
  }
}
```

## Configuration Examples

### Example 1: Basic VPC Configuration

```hcl
# terraform.tfvars
global_settings = {
  default_vpc_config = {
    vpc_id = "vpc-12345678"
    subnet_ids = [
      "subnet-12345678",
      "subnet-87654321"
    ]
    security_group_ids = [
      "sg-12345678"
    ]
  }
}

lambda_deployments = {
  "prod-main" = {
    function_name        = "prod-s3-forwarder"
    source_bucket_name   = "prod-bucket"
    environment         = "prod"
    # Uses global VPC configuration
  }
}
```

### Example 2: Mixed VPC Configuration

```hcl
global_settings = {
  default_vpc_config = {
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    security_group_ids = ["sg-12345678"]
  }
}

lambda_deployments = {
  "prod-vpc" = {
    function_name        = "prod-vpc-forwarder"
    source_bucket_name   = "prod-bucket"
    environment         = "prod"
    # Uses global VPC configuration
  }
  
  "staging-no-vpc" = {
    function_name        = "staging-forwarder"
    source_bucket_name   = "staging-bucket"
    environment         = "staging"
    vpc_config = null  # Override: no VPC
  }
}
```

### Example 3: Multiple VPCs

```hcl
lambda_deployments = {
  "prod-main" = {
    function_name        = "prod-main-forwarder"
    source_bucket_name   = "prod-main-bucket"
    environment         = "prod"
    vpc_config = {
      vpc_id = "vpc-12345678"
      subnet_ids = ["subnet-12345678", "subnet-87654321"]
      security_group_ids = ["sg-12345678"]
    }
  }
  
  "prod-critical" = {
    function_name        = "prod-critical-forwarder"
    source_bucket_name   = "prod-critical-bucket"
    environment         = "prod"
    vpc_config = {
      vpc_id = "vpc-87654321"  # Different VPC
      subnet_ids = ["subnet-87654321", "subnet-12345678"]
      security_group_ids = ["sg-87654321", "sg-12345678"]
    }
  }
}
```

## Security Considerations

### 1. Security Groups

Configure security groups with minimal required access:

```hcl
# Minimal security group for Lambda
resource "aws_security_group" "lambda_minimal" {
  name        = "lambda-minimal-sg"
  description = "Minimal security group for Lambda functions"
  vpc_id      = aws_vpc.lambda_vpc.id
  
  # Allow outbound HTTPS (for AWS services)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow outbound HTTP (if needed)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow specific database access
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
  }
}
```

### 2. Network ACLs

Consider using Network ACLs for additional security:

```hcl
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.lambda_vpc.id
  
  # Allow outbound HTTPS
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  
  # Allow ephemeral ports
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  
  tags = {
    Name = "private-nacl"
  }
}
```

## Network Requirements

### 1. Internet Access

Lambda functions in VPC need internet access for:
- AWS SDK calls
- External API calls
- Package downloads

Ensure NAT Gateway is configured:

```hcl
# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lambda_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }
  
  tags = {
    Name = "private-rt"
  }
}

# Associate private subnets with route table
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

### 2. VPC Endpoints (Optional)

For enhanced security, use VPC endpoints for AWS services:

```hcl
# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.lambda_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  
  tags = {
    Name = "s3-endpoint"
  }
}

# Lambda VPC Endpoint
resource "aws_vpc_endpoint" "lambda" {
  vpc_id            = aws_vpc.lambda_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.lambda"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  
  private_dns_enabled = true
  
  tags = {
    Name = "lambda-endpoint"
  }
}
```

## Troubleshooting

### Common Issues

1. **Cold Start Delays**
   - VPC Lambda functions have longer cold start times
   - Consider using provisioned concurrency for critical functions

2. **Network Timeouts**
   - Check NAT Gateway configuration
   - Verify security group rules
   - Ensure sufficient NAT Gateway bandwidth

3. **DNS Resolution Issues**
   - Enable DNS hostnames in VPC
   - Configure DNS resolution settings

### Debugging Commands

```bash
# Check Lambda VPC configuration
aws lambda get-function --function-name your-function-name

# Test network connectivity
aws lambda invoke --function-name your-function-name \
  --payload '{"test": "network"}' response.json

# Check CloudWatch logs for network errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/your-function-name \
  --filter-pattern "ERROR"
```

## Best Practices

### 1. Subnet Configuration

- Use **private subnets** for Lambda functions
- Deploy across **multiple Availability Zones** for high availability
- Ensure **sufficient IP addresses** in subnets

### 2. Security Groups

- Follow **principle of least privilege**
- Use **specific port ranges** instead of 0-65535
- **Document** security group rules

### 3. Performance

- Use **NAT Gateway** instead of NAT Instance for better performance
- Consider **VPC endpoints** for high-traffic AWS services
- Monitor **NAT Gateway** metrics and costs

### 4. Cost Optimization

- **Share NAT Gateway** across multiple subnets
- Use **VPC endpoints** to reduce NAT Gateway traffic
- Monitor **data transfer costs**

### 5. Monitoring

```hcl
# CloudWatch metrics for VPC Lambda
resource "aws_cloudwatch_metric_alarm" "vpc_lambda_errors" {
  alarm_name          = "${var.function_name}-vpc-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  
  dimensions = {
    FunctionName = aws_lambda_function.lambda_function.function_name
  }
}
```

## Summary

VPC configuration for Lambda functions provides enhanced security and network isolation. Key points:

1. **Configure VPC at global or deployment level**
2. **Use private subnets with NAT Gateway**
3. **Apply minimal security group rules**
4. **Monitor performance and costs**
5. **Follow security best practices**

For more information, refer to the [AWS Lambda VPC documentation](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html). 