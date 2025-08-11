#!/usr/bin/env python3
"""
S3 Event Forwarder Lambda Function

Forwards S3 events to SQS queues and SNS topics based on configuration.
"""

import json
import logging
from typing import Dict, Any, Optional

from config import get_destinations_config
from destinations import DestinationForwarder

logger = logging.getLogger()
logger.setLevel(logging.INFO)

forwarder = DestinationForwarder()

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Main Lambda handler for S3 event forwarding."""
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract S3 event details
        s3_event = extract_s3_event(event)
        if not s3_event:
            return {'statusCode': 400, 'body': json.dumps({'error': 'No valid S3 event found'})}
        
        logger.info(f"Processing S3 event: {s3_event['eventName']} for bucket: {s3_event['bucketName']}")
        
        # Get and validate configuration
        config = get_destinations_config()
        if not config:
            return {'statusCode': 500, 'body': json.dumps({'error': 'Failed to load configuration'})}
        
        # Forward event to destinations
        results = forward_to_destinations(s3_event, config)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'S3 event forwarded successfully',
                'results': results,
                'event': s3_event
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing S3 event: {str(e)}", exc_info=True)
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

def extract_s3_event(event: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Extract S3 event details from various event formats."""
    try:
        # Direct S3 event
        if 'Records' in event:
            for record in event['Records']:
                if record.get('eventSource') == 'aws:s3':
                    return {
                        'eventName': record['eventName'],
                        'bucketName': record['s3']['bucket']['name'],
                        'objectKey': record['s3']['object']['key'],
                        'eventTime': record['eventTime'],
                        'eventSource': record['eventSource'],
                        'awsRegion': record['awsRegion'],
                        'rawEvent': record
                    }
        
        # CloudWatch Events S3 event
        elif 'detail-type' in event and event['detail-type'] == 'Object Created:Put':
            detail = event.get('detail', {})
            return {
                'eventName': 'ObjectCreated:Put',
                'bucketName': detail.get('bucket', {}).get('name'),
                'objectKey': detail.get('object', {}).get('key'),
                'eventTime': event.get('time'),
                'eventSource': 'aws:s3',
                'awsRegion': event.get('region'),
                'rawEvent': event
            }
        
        # EventBridge S3 event
        elif 'source' in event and event['source'] == 'aws.s3':
            detail = event.get('detail', {})
            return {
                'eventName': detail.get('eventName', 'Unknown'),
                'bucketName': detail.get('requestParameters', {}).get('bucketName'),
                'objectKey': detail.get('requestParameters', {}).get('key'),
                'eventTime': event.get('time'),
                'eventSource': 'aws.s3',
                'awsRegion': event.get('region'),
                'rawEvent': event
            }
        
        logger.warning(f"Unsupported event structure: {json.dumps(event)}")
        return None
        
    except Exception as e:
        logger.error(f"Error extracting S3 event: {str(e)}")
        return None

def forward_to_destinations(s3_event: Dict[str, Any], config: Dict[str, Any]) -> Dict[str, Any]:
    """Forward S3 event to all configured destinations."""
    results = {'successful': [], 'failed': [], 'total_processed': 0}
    
    # Forward to SQS queues
    queues = config.get('sqs_queues', [])
    if queues:
        for queue_config in queues:
            # Check if queue is enabled
            if queue_config.get('enabled', True):  # Default to True if not specified
                result = forwarder.forward_to_sqs(s3_event, queue_config)
                _add_result(results, 'sqs', queue_config['name'], result)
            else:
                logger.info(f"Skipping disabled SQS queue: {queue_config.get('name', 'unknown')}")
    else:
        logger.info("No SQS queues configured")
    
    # Forward to SNS topics
    topics = config.get('sns_topics', [])
    if topics:
        for topic_config in topics:
            # Check if topic is enabled
            if topic_config.get('enabled', True):  # Default to True if not specified
                result = forwarder.forward_to_sns(s3_event, topic_config)
                _add_result(results, 'sns', topic_config['name'], result)
            else:
                logger.info(f"Skipping disabled SNS topic: {topic_config.get('name', 'unknown')}")
    else:
        logger.info("No SNS topics configured")
    
    logger.info(f"Forwarded event to {len(results['successful'])} successful and {len(results['failed'])} failed destinations")
    return results

def _add_result(results: Dict[str, Any], dest_type: str, dest_name: str, result: Dict[str, Any]) -> None:
    """Add forwarding result to results dictionary."""
    results['total_processed'] += 1
    if result['success']:
        results['successful'].append({
            'type': dest_type,
            'destination': dest_name,
            'message_id': result.get('message_id')
        })
    else:
        results['failed'].append({
            'type': dest_type,
            'destination': dest_name,
            'error': result.get('error')
        }) 