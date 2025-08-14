import json
import logging
import os
from typing import Dict, Any
from destinations import DestinationManager

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda function handler for S3 event forwarding.
    
    Args:
        event: S3 event data
        context: Lambda context
        
    Returns:
        Response dictionary with status and results
    """
    try:
        # Log the incoming event
        logger.info(f"Received S3 event: {json.dumps(event, default=str)}")
        
        # Extract environment information
        environment = os.environ.get('ENVIRONMENT', 'unknown')
        source_bucket = os.environ.get('SOURCE_BUCKET', 'unknown')
        deployment_key = os.environ.get('DEPLOYMENT_KEY', 'unknown')
        
        logger.info(f"Processing event for environment: {environment}, bucket: {source_bucket}, deployment: {deployment_key}")
        
        # Initialize destination manager
        destination_manager = DestinationManager()
        
        # Log currently enabled destinations for verification
        enabled_destinations_summary = destination_manager.get_enabled_destinations_summary()
        logger.info("=== DESTINATION VERIFICATION ===")
        logger.info(enabled_destinations_summary)
        logger.info("=== END DESTINATION VERIFICATION ===")
        
        # Get destination status for logging
        dest_status = destination_manager.get_destination_status()
        logger.info(f"Destination status: {json.dumps(dest_status, default=str)}")
        
        # Process each S3 event record
        results = []
        success_count = 0
        error_count = 0
        
        for record in event.get('Records', []):
            try:
                # Extract S3 event details
                s3_event = record.get('s3', {})
                bucket_name = s3_event.get('bucket', {}).get('name', 'unknown')
                object_key = s3_event.get('object', {}).get('key', 'unknown')
                event_name = record.get('eventName', 'unknown')
                
                logger.info(f"Processing S3 event: {event_name} for bucket: {bucket_name}, key: {object_key}")
                
                # Forward the event to destinations
                forwarding_result = destination_manager.forward_event(record)
                results.append({
                    'record': {
                        'event_name': event_name,
                        'bucket': bucket_name,
                        'key': object_key
                    },
                    'forwarding_result': forwarding_result
                })
                
                if forwarding_result['success']:
                    success_count += 1
                    logger.info(f"Successfully processed event: {event_name}")
                else:
                    error_count += 1
                    logger.error(f"Failed to process event: {event_name} - {forwarding_result['message']}")
                    
            except Exception as e:
                error_count += 1
                logger.error(f"Error processing S3 record: {str(e)}")
                results.append({
                    'record': record,
                    'error': str(e)
                })
        
        # Prepare response
        overall_success = error_count == 0
        response = {
            'statusCode': 200 if overall_success else 500,
            'body': {
                'success': overall_success,
                'message': f'Processed {len(event.get("Records", []))} records: {success_count} successful, {error_count} failed',
                'environment': environment,
                'source_bucket': source_bucket,
                'deployment_key': deployment_key,
                'destination_status': dest_status,
                'enabled_destinations': destination_manager.get_enabled_destinations_list(),
                'results': results
            }
        }
        
        if overall_success:
            logger.info(f"Lambda execution completed successfully: {response['body']['message']}")
        else:
            logger.error(f"Lambda execution completed with errors: {response['body']['message']}")
        
        return response
        
    except Exception as e:
        logger.error(f"Unexpected error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': {
                'success': False,
                'error': str(e),
                'message': 'Internal server error'
            }
        } 