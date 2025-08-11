#!/usr/bin/env python3
"""
Test script to verify multiple destinations support in S3 Event Forwarder Lambda Function
"""

import json
import sys
import os

# Add the current directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_multiple_destinations():
    """Test multiple destinations support."""
    print("\n🎯 Testing Multiple Destinations Support...")
    print("=" * 60)
    
    try:
        from main import lambda_handler
        from config import get_destinations_config
        
        # Test configuration with multiple destinations
        test_config = {
            "sqs_queues": [
                {
                    "name": "processing-queue-1",
                    "url": "https://sqs.us-east-1.amazonaws.com/123456789012/processing-queue-1",
                    "arn": "arn:aws:sqs:us-east-1:123456789012:processing-queue-1",
                    "enabled": True
                },
                {
                    "name": "processing-queue-2",
                    "url": "https://sqs.us-east-1.amazonaws.com/123456789012/processing-queue-2",
                    "arn": "arn:aws:sqs:us-east-1:123456789012:processing-queue-2",
                    "enabled": True
                },
                {
                    "name": "backup-queue",
                    "url": "https://sqs.us-east-1.amazonaws.com/123456789012/backup-queue",
                    "arn": "arn:aws:sqs:us-east-1:123456789012:backup-queue",
                    "enabled": True
                }
            ],
            "sns_topics": [
                {
                    "name": "notifications-topic-1",
                    "arn": "arn:aws:sns:us-east-1:123456789012:notifications-topic-1",
                    "enabled": True
                },
                {
                    "name": "notifications-topic-2",
                    "arn": "arn:aws:sns:us-east-1:123456789012:notifications-topic-2",
                    "enabled": True
                },
                {
                    "name": "alerts-topic",
                    "arn": "arn:aws:sns:us-east-1:123456789012:alerts-topic",
                    "enabled": True
                }
            ]
        }
        
        print(f"Test configuration with multiple destinations:")
        print(f"  - SQS Queues: {len(test_config['sqs_queues'])}")
        print(f"  - SNS Topics: {len(test_config['sns_topics'])}")
        
        # Test S3 event
        test_event = {
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
        
        print(f"\nTesting with S3 event: {test_event['Records'][0]['eventName']}")
        
        # Mock the configuration loading to use our test config
        import config
        original_get_config = config.get_destinations_config
        
        def mock_get_config():
            return test_config
        
        config.get_destinations_config = mock_get_config
        
        try:
            # Test the lambda handler
            result = lambda_handler(test_event, None)
            
            print(f"\n✅ Lambda handler result:")
            print(f"  Status Code: {result.get('statusCode')}")
            
            if result.get('statusCode') == 200:
                body = json.loads(result.get('body', '{}'))
                results = body.get('results', {})
                
                print(f"  Total Processed: {results.get('total_processed', 0)}")
                print(f"  Successful: {len(results.get('successful', []))}")
                print(f"  Failed: {len(results.get('failed', []))}")
                
                # Check if all destinations were processed
                expected_total = len(test_config['sqs_queues']) + len(test_config['sns_topics'])
                actual_total = results.get('total_processed', 0)
                
                if actual_total == expected_total:
                    print(f"  ✅ All {expected_total} destinations were processed")
                else:
                    print(f"  ❌ Expected {expected_total} destinations, but processed {actual_total}")
                
                # Show successful destinations
                if results.get('successful'):
                    print(f"\n  Successful destinations:")
                    for dest in results['successful']:
                        print(f"    - {dest['type'].upper()}: {dest['destination']}")
                
                # Show failed destinations
                if results.get('failed'):
                    print(f"\n  Failed destinations:")
                    for dest in results['failed']:
                        print(f"    - {dest['type'].upper()}: {dest['destination']} - {dest['error']}")
                
            else:
                print(f"  ❌ Lambda handler failed with status code: {result.get('statusCode')}")
                print(f"  Error: {result.get('body', 'Unknown error')}")
                
        finally:
            # Restore original function
            config.get_destinations_config = original_get_config
        
    except Exception as e:
        print(f"❌ Error testing multiple destinations: {str(e)}")
        import traceback
        traceback.print_exc()

def test_destination_processing_logic():
    """Test the destination processing logic directly."""
    print("\n🔍 Testing Destination Processing Logic...")
    print("=" * 50)
    
    try:
        from main import forward_to_destinations
        
        # Test configuration
        test_config = {
            "sqs_queues": [
                {"name": "queue1", "url": "http://test1", "enabled": True},
                {"name": "queue2", "url": "http://test2", "enabled": True}
            ],
            "sns_topics": [
                {"name": "topic1", "arn": "arn:test1", "enabled": True},
                {"name": "topic2", "arn": "arn:test2", "enabled": True}
            ]
        }
        
        test_s3_event = {
            "eventName": "ObjectCreated:Put",
            "bucketName": "test-bucket",
            "objectKey": "test/file.txt",
            "eventTime": "2024-12-01T10:00:00.000Z",
            "eventSource": "aws:s3",
            "awsRegion": "us-east-1"
        }
        
        print(f"Testing with {len(test_config['sqs_queues'])} SQS queues and {len(test_config['sns_topics'])} SNS topics")
        
        # Test the forwarding logic
        results = forward_to_destinations(test_s3_event, test_config)
        
        print(f"Results:")
        print(f"  Total Processed: {results.get('total_processed', 0)}")
        print(f"  Successful: {len(results.get('successful', []))}")
        print(f"  Failed: {len(results.get('failed', []))}")
        
        # Verify all destinations were processed
        expected_total = len(test_config['sqs_queues']) + len(test_config['sns_topics'])
        actual_total = results.get('total_processed', 0)
        
        if actual_total == expected_total:
            print(f"  ✅ All {expected_total} destinations were processed")
        else:
            print(f"  ❌ Expected {expected_total} destinations, but processed {actual_total}")
        
    except Exception as e:
        print(f"❌ Error testing destination processing logic: {str(e)}")

def test_configuration_structure():
    """Test configuration structure for multiple destinations."""
    print("\n⚙️ Testing Configuration Structure...")
    print("=" * 40)
    
    try:
        from config import _ensure_structure
        
        # Test various configuration structures
        test_cases = [
            {
                "name": "Multiple SQS and SNS",
                "config": {
                    "sqs_queues": [
                        {"name": "queue1", "url": "http://test1", "enabled": True},
                        {"name": "queue2", "url": "http://test2", "enabled": True}
                    ],
                    "sns_topics": [
                        {"name": "topic1", "arn": "arn:test1", "enabled": True},
                        {"name": "topic2", "arn": "arn:test2", "enabled": True}
                    ]
                }
            },
            {
                "name": "Empty arrays",
                "config": {
                    "sqs_queues": [],
                    "sns_topics": []
                }
            },
            {
                "name": "Missing arrays",
                "config": {}
            },
            {
                "name": "Mixed enabled/disabled",
                "config": {
                    "sqs_queues": [
                        {"name": "queue1", "url": "http://test1", "enabled": True},
                        {"name": "queue2", "url": "http://test2", "enabled": False}
                    ],
                    "sns_topics": [
                        {"name": "topic1", "arn": "arn:test1", "enabled": True},
                        {"name": "topic2", "arn": "arn:test2", "enabled": False}
                    ]
                }
            }
        ]
        
        for test_case in test_cases:
            print(f"\nTesting: {test_case['name']}")
            ensured_config = _ensure_structure(test_case['config'])
            
            sqs_count = len(ensured_config.get('sqs_queues', []))
            sns_count = len(ensured_config.get('sns_topics', []))
            
            print(f"  SQS Queues: {sqs_count}")
            print(f"  SNS Topics: {sns_count}")
            
            # Verify structure
            if isinstance(ensured_config.get('sqs_queues'), list) and isinstance(ensured_config.get('sns_topics'), list):
                print(f"  ✅ Valid structure")
            else:
                print(f"  ❌ Invalid structure")
        
    except Exception as e:
        print(f"❌ Error testing configuration structure: {str(e)}")

def test_enabled_field_functionality():
    """Test the enabled field functionality."""
    print("\n🔘 Testing Enabled Field Functionality...")
    print("=" * 50)
    
    try:
        from main import forward_to_destinations
        
        # Test configuration with mixed enabled/disabled destinations
        test_config = {
            "sqs_queues": [
                {"name": "enabled-queue", "url": "http://test1", "enabled": True},
                {"name": "disabled-queue", "url": "http://test2", "enabled": False},
                {"name": "default-enabled-queue", "url": "http://test3"}  # No enabled field
            ],
            "sns_topics": [
                {"name": "enabled-topic", "arn": "arn:test1", "enabled": True},
                {"name": "disabled-topic", "arn": "arn:test2", "enabled": False},
                {"name": "default-enabled-topic", "arn": "arn:test3"}  # No enabled field
            ]
        }
        
        test_s3_event = {
            "eventName": "ObjectCreated:Put",
            "bucketName": "test-bucket",
            "objectKey": "test/file.txt",
            "eventTime": "2024-12-01T10:00:00.000Z",
            "eventSource": "aws:s3",
            "awsRegion": "us-east-1"
        }
        
        print(f"Testing with mixed enabled/disabled destinations:")
        print(f"  - SQS Queues: 2 enabled, 1 disabled")
        print(f"  - SNS Topics: 2 enabled, 1 disabled")
        
        # Test the forwarding logic
        results = forward_to_destinations(test_s3_event, test_config)
        
        print(f"\nResults:")
        print(f"  Total Processed: {results.get('total_processed', 0)}")
        print(f"  Successful: {len(results.get('successful', []))}")
        print(f"  Failed: {len(results.get('failed', []))}")
        
        # Verify only enabled destinations were processed
        expected_enabled = 4  # 2 enabled SQS + 2 enabled SNS
        actual_processed = results.get('total_processed', 0)
        
        if actual_processed == expected_enabled:
            print(f"  ✅ Correctly processed {expected_enabled} enabled destinations")
        else:
            print(f"  ❌ Expected {expected_enabled} enabled destinations, but processed {actual_processed}")
        
        # Show which destinations were processed
        if results.get('successful'):
            print(f"\n  Processed destinations:")
            for dest in results['successful']:
                print(f"    - {dest['type'].upper()}: {dest['destination']}")
        
        # Show which destinations were skipped
        skipped_destinations = [
            "disabled-queue", "disabled-topic"
        ]
        print(f"\n  Skipped destinations (disabled):")
        for dest in skipped_destinations:
            print(f"    - {dest}")
        
    except Exception as e:
        print(f"❌ Error testing enabled field functionality: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("🚀 Multiple Destinations Support Test Suite")
    print("=" * 60)
    
    test_configuration_structure()
    test_destination_processing_logic()
    test_multiple_destinations()
    test_enabled_field_functionality()
    
    print("\n🎉 Multiple destinations testing completed!")
    print("\nNote: This test runs locally and may not have access to AWS services.")
    print("For full testing, deploy the Lambda function and test with real AWS resources.") 