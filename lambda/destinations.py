#!/usr/bin/env python3
"""
Destinations module for S3 Event Forwarder

Handles forwarding S3 events to SQS queues and SNS topics.
"""

import json
import logging
import boto3
from typing import Dict, Any
from botocore.exceptions import ClientError

logger = logging.getLogger()

class DestinationForwarder:
    """Handles forwarding events to AWS destinations."""
    
    def __init__(self):
        self.sqs_client = boto3.client('sqs')
        self.sns_client = boto3.client('sns')
    
    def forward_to_sqs(self, s3_event: Dict[str, Any], queue_config: Dict[str, Any]) -> Dict[str, Any]:
        """Forward S3 event to SQS queue."""
        try:
            queue_url = queue_config.get('url')
            queue_name = queue_config.get('name', 'unknown')
            
            if not queue_url:
                return {'success': False, 'error': f"Missing queue URL for {queue_name}"}
            
            message_body = self._prepare_sqs_message(s3_event, queue_config)
            response = self.sqs_client.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(message_body),
                MessageAttributes=self._get_sqs_attributes(s3_event)
            )
            
            logger.info(f"Successfully forwarded to SQS queue {queue_name}. Message ID: {response.get('MessageId')}")
            return {'success': True, 'message_id': response.get('MessageId')}
            
        except ClientError as e:
            error_msg = f"Error forwarding to SQS queue {queue_config.get('name', 'unknown')}: {str(e)}"
            logger.error(error_msg)
            return {'success': False, 'error': error_msg}
        except Exception as e:
            error_msg = f"Unexpected error forwarding to SQS: {str(e)}"
            logger.error(error_msg)
            return {'success': False, 'error': error_msg}
    
    def forward_to_sns(self, s3_event: Dict[str, Any], topic_config: Dict[str, Any]) -> Dict[str, Any]:
        """Forward S3 event to SNS topic."""
        try:
            topic_arn = topic_config.get('arn')
            topic_name = topic_config.get('name', 'unknown')
            
            if not topic_arn:
                return {'success': False, 'error': f"Missing topic ARN for {topic_name}"}
            
            message_body = self._prepare_sns_message(s3_event, topic_config)
            response = self.sns_client.publish(
                TopicArn=topic_arn,
                Message=json.dumps(message_body),
                Subject=f"S3 Event: {s3_event.get('eventName', 'Unknown')} - {s3_event.get('bucketName', 'Unknown')}",
                MessageAttributes=self._get_sns_attributes(s3_event)
            )
            
            logger.info(f"Successfully forwarded to SNS topic {topic_name}. Message ID: {response.get('MessageId')}")
            return {'success': True, 'message_id': response.get('MessageId')}
            
        except ClientError as e:
            error_msg = f"Error forwarding to SNS topic {topic_config.get('name', 'unknown')}: {str(e)}"
            logger.error(error_msg)
            return {'success': False, 'error': error_msg}
        except Exception as e:
            error_msg = f"Unexpected error forwarding to SNS: {str(e)}"
            logger.error(error_msg)
            return {'success': False, 'error': error_msg}
    
    def _prepare_sqs_message(self, s3_event: Dict[str, Any], queue_config: Dict[str, Any]) -> Dict[str, Any]:
        """Prepare message body for SQS."""
        return {
            'event_type': 's3_event',
            'event_name': s3_event.get('eventName'),
            'bucket_name': s3_event.get('bucketName'),
            'object_key': s3_event.get('objectKey'),
            'event_time': s3_event.get('eventTime'),
            'event_source': s3_event.get('eventSource'),
            'aws_region': s3_event.get('awsRegion'),
            'destination_type': 'sqs',
            'destination_name': queue_config.get('name'),
            'destination_url': queue_config.get('url'),
            'raw_event': s3_event.get('rawEvent', {}),
            'timestamp': s3_event.get('eventTime')
        }
    
    def _prepare_sns_message(self, s3_event: Dict[str, Any], topic_config: Dict[str, Any]) -> Dict[str, Any]:
        """Prepare message body for SNS."""
        return {
            'event_type': 's3_event',
            'event_name': s3_event.get('eventName'),
            'bucket_name': s3_event.get('bucketName'),
            'object_key': s3_event.get('objectKey'),
            'event_time': s3_event.get('eventTime'),
            'event_source': s3_event.get('eventSource'),
            'aws_region': s3_event.get('awsRegion'),
            'destination_type': 'sns',
            'destination_name': topic_config.get('name'),
            'destination_arn': topic_config.get('arn'),
            'raw_event': s3_event.get('rawEvent', {}),
            'timestamp': s3_event.get('eventTime')
        }
    
    def _get_sqs_attributes(self, s3_event: Dict[str, Any]) -> Dict[str, Any]:
        """Get SQS message attributes."""
        return {
            'EventType': {'StringValue': s3_event.get('eventName', 'Unknown'), 'DataType': 'String'},
            'BucketName': {'StringValue': s3_event.get('bucketName', 'Unknown'), 'DataType': 'String'},
            'ObjectKey': {'StringValue': s3_event.get('objectKey', 'Unknown'), 'DataType': 'String'},
            'EventTime': {'StringValue': s3_event.get('eventTime', 'Unknown'), 'DataType': 'String'}
        }
    
    def _get_sns_attributes(self, s3_event: Dict[str, Any]) -> Dict[str, Any]:
        """Get SNS message attributes."""
        return {
            'EventType': {'StringValue': s3_event.get('eventName', 'Unknown'), 'DataType': 'String'},
            'BucketName': {'StringValue': s3_event.get('bucketName', 'Unknown'), 'DataType': 'String'},
            'ObjectKey': {'StringValue': s3_event.get('objectKey', 'Unknown'), 'DataType': 'String'},
            'EventTime': {'StringValue': s3_event.get('eventTime', 'Unknown'), 'DataType': 'String'}
        } 