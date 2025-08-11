#!/usr/bin/env python3
"""
Test script for S3 Event Forwarder Lambda Function

This script provides local testing capabilities for the Lambda function.
"""

import json
import sys
import os

# Add the current directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_configuration():
    """Test the configuration loading functionality."""
    print("\n🔧 Testing Configuration Loading...")
    print("=" * 50)
    
    try:
        from config import get_destinations_config, _ensure_structure
        
        # Test default configuration
        config = get_destinations_config()
        print(f"Loaded configuration: {json.dumps(config, indent=2)}")
        
        # Test empty arrays configuration
        print("\nTesting empty arrays configuration...")
        empty_config = {"sqs_queues": [], "sns_topics": []}
        ensured_config = _ensure_structure(empty_config)
        print(f"Empty config ensured: {json.dumps(ensured_config, indent=2)}")
        
        # Test partial configuration (missing arrays)
        print("\nTesting partial configuration...")
        partial_config = {"some_other_key": "value"}
        ensured_partial = _ensure_structure(partial_config)
        print(f"Partial config ensured: {json.dumps(ensured_partial, indent=2)}")
        
    except Exception as e:
        print(f"❌ Error testing configuration: {str(e)}")

def test_destinations():
    """Test the destinations module."""
    print("\n🎯 Testing Destinations Module...")
    print("=" * 50)
    
    try:
        from destinations import DestinationForwarder
        
        # Create forwarder instance
        forwarder = DestinationForwarder()
        print("✅ DestinationForwarder created successfully")
        
        # Test message preparation
        s3_event = {
            'eventName': 'ObjectCreated:Put',
            'bucketName': 'test-bucket',
            'objectKey': 'test/file.txt',
            'eventTime': '2024-12-01T10:00:00.000Z',
            'eventSource': 'aws:s3',
            'awsRegion': 'us-east-1'
        }
        
        queue_config = {
            'name': 'test-queue',
            'url': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue',
            'arn': 'arn:aws:sqs:us-east-1:123456789012:test-queue'
        }
        
        topic_config = {
            'name': 'test-topic',
            'arn': 'arn:aws:sns:us-east-1:123456789012:test-topic'
        }
        
        # Test SQS message preparation
        sqs_message = forwarder._prepare_sqs_message(s3_event, queue_config)
        print(f"SQS message prepared: {json.dumps(sqs_message, indent=2)}")
        
        # Test SNS message preparation
        sns_message = forwarder._prepare_sns_message(s3_event, topic_config)
        print(f"SNS message prepared: {json.dumps(sns_message, indent=2)}")
        
    except Exception as e:
        print(f"❌ Error testing destinations: {str(e)}")

def test_s3_event_forwarding():
    """Test S3 event forwarding functionality."""
    print("\n📤 Testing S3 Event Forwarding...")
    print("=" * 50)
    
    try:
        from main import lambda_handler, extract_s3_event
        
        # Test 1: Standard S3 Event
        print("\n1. Testing Standard S3 Event...")
        test_event_1 = {
            "Records": [
                {
                    "eventVersion": "2.1",
                    "eventSource": "aws:s3",
                    "awsRegion": "us-east-1",
                    "eventTime": "2024-12-01T10:00:00.000Z",
                    "eventName": "ObjectCreated:Put",
                    "s3": {
                        "bucket": {"name": "test-bucket"},
                        "object": {"key": "test/file.txt"}
                    }
                }
            ]
        }
        
        result_1 = lambda_handler(test_event_1, None)
        print(f"Result: {json.dumps(result_1, indent=2)}")
        
        # Test 2: Empty Configuration
        print("\n2. Testing Empty Configuration...")
        test_event_2 = {
            "Records": [
                {
                    "eventVersion": "2.1",
                    "eventSource": "aws:s3",
                    "awsRegion": "us-east-1",
                    "eventTime": "2024-12-01T10:00:00.000Z",
                    "eventName": "ObjectCreated:Put",
                    "s3": {
                        "bucket": {"name": "test-bucket"},
                        "object": {"key": "test/file.txt"}
                    }
                }
            ]
        }
        
        result_2 = lambda_handler(test_event_2, None)
        print(f"Result: {json.dumps(result_2, indent=2)}")
        
        # Test 3: Invalid Event
        print("\n3. Testing Invalid Event...")
        test_event_3 = {"invalid": "event"}
        result_3 = lambda_handler(test_event_3, None)
        print(f"Result: {json.dumps(result_3, indent=2)}")
        
    except Exception as e:
        print(f"❌ Error testing S3 event forwarding: {str(e)}")

if __name__ == "__main__":
    print("🚀 S3 Event Forwarder Lambda Function - Test Suite")
    print("=" * 60)
    
    test_configuration()
    test_destinations()
    test_s3_event_forwarding()
    
    print("\n🎉 All tests completed!")
    print("\nNote: This test runs locally and may not have access to AWS services.")
    print("For full testing, deploy the Lambda function and test with real AWS resources.") 