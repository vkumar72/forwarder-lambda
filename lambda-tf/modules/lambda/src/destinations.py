import json
import boto3
import logging
from typing import Dict, List, Any, Optional
from botocore.exceptions import ClientError, NoCredentialsError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class DestinationManager:
    """
    Manages forwarding S3 events to configured destinations (SQS and SNS).
    Only forwards to destinations that are enabled in the configuration.
    """
    
    def __init__(self, destinations_file: str = "destinations.json"):
        """
        Initialize the DestinationManager.
        
        Args:
            destinations_file: Path to the destinations configuration file
        """
        self.destinations_file = destinations_file
        self.destinations = self._load_destinations()
        self.sqs_client = boto3.client('sqs')
        self.sns_client = boto3.client('sns')
        
    def _load_destinations(self) -> List[Dict[str, Any]]:
        """
        Load destinations configuration from JSON file.
        
        Returns:
            List of destination configurations
        """
        try:
            with open(self.destinations_file, 'r') as f:
                config = json.load(f)
                destinations = config.get('destinations', [])
                
                # Filter only enabled destinations
                enabled_destinations = [
                    dest for dest in destinations 
                    if dest.get('enabled', False)
                ]
                
                logger.info(f"Loaded {len(enabled_destinations)} enabled destinations from {len(destinations)} total destinations")
                return enabled_destinations
                
        except FileNotFoundError:
            logger.warning(f"Destinations file {self.destinations_file} not found. No destinations will be used.")
            return []
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in destinations file: {e}")
            return []
        except Exception as e:
            logger.error(f"Error loading destinations: {e}")
            return []
    
    def get_enabled_destinations_summary(self) -> str:
        """
        Get a formatted summary of currently enabled destinations for logging.
        
        Returns:
            Formatted string with enabled destinations information
        """
        if not self.destinations:
            return "No enabled destinations configured"
        
        summary_lines = ["Currently Enabled Destinations:"]
        
        for i, dest in enumerate(self.destinations, 1):
            dest_name = dest.get('name', 'unknown')
            dest_type = dest.get('type', 'unknown').upper()
            dest_arn = dest.get('arn', 'no-arn')
            description = dest.get('description', 'No description')
            
            summary_lines.append(f"  {i}. {dest_name} ({dest_type})")
            summary_lines.append(f"     ARN: {dest_arn}")
            summary_lines.append(f"     Description: {description}")
            summary_lines.append("")
        
        summary_lines.append(f"Total Enabled Destinations: {len(self.destinations)}")
        
        return "\n".join(summary_lines)
    
    def get_enabled_destinations_list(self) -> List[Dict[str, str]]:
        """
        Get a simple list of enabled destinations with key information.
        
        Returns:
            List of dictionaries with destination information
        """
        return [
            {
                'name': dest.get('name', 'unknown'),
                'type': dest.get('type', 'unknown'),
                'arn': dest.get('arn', 'no-arn'),
                'description': dest.get('description', 'No description')
            }
            for dest in self.destinations
        ]
    
    def forward_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """
        Forward S3 event to all enabled destinations.
        
        Args:
            event: S3 event data
            
        Returns:
            Dictionary with forwarding results
        """
        if not self.destinations:
            logger.warning("No enabled destinations configured")
            return {
                'success': True,
                'message': 'No destinations to forward to',
                'results': []
            }
        
        results = []
        success_count = 0
        error_count = 0
        
        for destination in self.destinations:
            try:
                result = self._forward_to_destination(destination, event)
                results.append(result)
                
                if result['success']:
                    success_count += 1
                else:
                    error_count += 1
                    
            except Exception as e:
                logger.error(f"Error forwarding to destination {destination.get('name', 'unknown')}: {e}")
                results.append({
                    'destination': destination.get('name', 'unknown'),
                    'success': False,
                    'error': str(e)
                })
                error_count += 1
        
        overall_success = error_count == 0
        
        logger.info(f"Forwarding completed: {success_count} successful, {error_count} failed")
        
        return {
            'success': overall_success,
            'message': f'Forwarded to {success_count} destinations, {error_count} failed',
            'results': results
        }
    
    def _forward_to_destination(self, destination: Dict[str, Any], event: Dict[str, Any]) -> Dict[str, Any]:
        """
        Forward event to a specific destination.
        
        Args:
            destination: Destination configuration
            event: S3 event data
            
        Returns:
            Result of the forwarding operation
        """
        dest_name = destination.get('name', 'unknown')
        dest_type = destination.get('type', '').lower()
        dest_arn = destination.get('arn', '')
        
        if not dest_arn:
            return {
                'destination': dest_name,
                'success': False,
                'error': 'No ARN provided for destination'
            }
        
        try:
            if dest_type == 'sqs':
                return self._forward_to_sqs(destination, event)
            elif dest_type == 'sns':
                return self._forward_to_sns(destination, event)
            else:
                return {
                    'destination': dest_name,
                    'success': False,
                    'error': f'Unsupported destination type: {dest_type}'
                }
                
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            # Handle specific permission errors
            if error_code in ['AccessDenied', 'UnauthorizedOperation']:
                logger.error(f"Permission denied for destination {dest_name}: {error_message}")
                return {
                    'destination': dest_name,
                    'success': False,
                    'error': f'Permission denied: {error_message}',
                    'error_code': error_code
                }
            elif error_code in ['ResourceNotFoundException', 'InvalidParameter']:
                logger.error(f"Invalid destination {dest_name}: {error_message}")
                return {
                    'destination': dest_name,
                    'success': False,
                    'error': f'Invalid destination: {error_message}',
                    'error_code': error_code
                }
            else:
                logger.error(f"AWS error for destination {dest_name}: {error_code} - {error_message}")
                return {
                    'destination': dest_name,
                    'success': False,
                    'error': f'AWS error: {error_message}',
                    'error_code': error_code
                }
                
        except NoCredentialsError:
            logger.error(f"No AWS credentials available for destination {dest_name}")
            return {
                'destination': dest_name,
                'success': False,
                'error': 'No AWS credentials available'
            }
        except Exception as e:
            logger.error(f"Unexpected error for destination {dest_name}: {e}")
            return {
                'destination': dest_name,
                'success': False,
                'error': f'Unexpected error: {str(e)}'
            }
    
    def _forward_to_sqs(self, destination: Dict[str, Any], event: Dict[str, Any]) -> Dict[str, Any]:
        """
        Forward event to SQS queue.
        
        Args:
            destination: SQS destination configuration
            event: S3 event data
            
        Returns:
            Result of the SQS operation
        """
        dest_name = destination.get('name', 'unknown')
        dest_arn = destination.get('arn', '')
        
        # Prepare message body
        message_body = {
            'source': 's3-event-forwarder',
            'destination': dest_name,
            'timestamp': event.get('time', ''),
            'event': event
        }
        
        try:
            response = self.sqs_client.send_message(
                QueueUrl=dest_arn,
                MessageBody=json.dumps(message_body),
                MessageAttributes={
                    'Source': {
                        'StringValue': 's3-event-forwarder',
                        'DataType': 'String'
                    },
                    'EventType': {
                        'StringValue': 'S3Event',
                        'DataType': 'String'
                    }
                }
            )
            
            logger.info(f"Successfully sent message to SQS queue {dest_name}: {response.get('MessageId', 'unknown')}")
            
            return {
                'destination': dest_name,
                'success': True,
                'message_id': response.get('MessageId'),
                'sqs_message_id': response.get('MessageId')
            }
            
        except ClientError as e:
            raise e
    
    def _forward_to_sns(self, destination: Dict[str, Any], event: Dict[str, Any]) -> Dict[str, Any]:
        """
        Forward event to SNS topic.
        
        Args:
            destination: SNS destination configuration
            event: S3 event data
            
        Returns:
            Result of the SNS operation
        """
        dest_name = destination.get('name', 'unknown')
        dest_arn = destination.get('arn', '')
        
        # Prepare message
        message = {
            'source': 's3-event-forwarder',
            'destination': dest_name,
            'timestamp': event.get('time', ''),
            'event': event
        }
        
        try:
            response = self.sns_client.publish(
                TopicArn=dest_arn,
                Message=json.dumps(message, default=str),
                Subject=f"S3 Event Notification - {dest_name}",
                MessageAttributes={
                    'Source': {
                        'DataType': 'String',
                        'StringValue': 's3-event-forwarder'
                    },
                    'EventType': {
                        'DataType': 'String',
                        'StringValue': 'S3Event'
                    }
                }
            )
            
            logger.info(f"Successfully published message to SNS topic {dest_name}: {response.get('MessageId', 'unknown')}")
            
            return {
                'destination': dest_name,
                'success': True,
                'message_id': response.get('MessageId'),
                'sns_message_id': response.get('MessageId')
            }
            
        except ClientError as e:
            raise e
    
    def get_destination_status(self) -> Dict[str, Any]:
        """
        Get status of all configured destinations.
        
        Returns:
            Dictionary with destination status information
        """
        status = {
            'total_destinations': len(self.destinations),
            'enabled_destinations': len([d for d in self.destinations if d.get('enabled', False)]),
            'destination_types': {},
            'destinations': []
        }
        
        for dest in self.destinations:
            dest_type = dest.get('type', 'unknown')
            status['destination_types'][dest_type] = status['destination_types'].get(dest_type, 0) + 1
            
            status['destinations'].append({
                'name': dest.get('name', 'unknown'),
                'type': dest_type,
                'enabled': dest.get('enabled', False),
                'arn': dest.get('arn', ''),
                'description': dest.get('description', '')
            })
        
        return status 

    def verify_destinations(self) -> Dict[str, Any]:
        """
        Verify and return information about currently configured destinations.
        This method can be used to check destinations without processing events.
        
        Returns:
            Dictionary with verification information
        """
        verification_info = {
            'timestamp': self._get_current_timestamp(),
            'destinations_file': self.destinations_file,
            'total_destinations_loaded': len(self.destinations),
            'enabled_destinations': self.get_enabled_destinations_list(),
            'destination_summary': self.get_enabled_destinations_summary(),
            'destination_types': {},
            'verification_status': 'success'
        }
        
        # Count destination types
        for dest in self.destinations:
            dest_type = dest.get('type', 'unknown')
            verification_info['destination_types'][dest_type] = verification_info['destination_types'].get(dest_type, 0) + 1
        
        # Add validation information
        validation_errors = []
        for dest in self.destinations:
            dest_name = dest.get('name', 'unknown')
            dest_arn = dest.get('arn', '')
            
            if not dest_arn:
                validation_errors.append(f"Destination '{dest_name}' has no ARN")
            elif dest.get('type', '').lower() not in ['sqs', 'sns']:
                validation_errors.append(f"Destination '{dest_name}' has unsupported type: {dest.get('type')}")
        
        if validation_errors:
            verification_info['validation_errors'] = validation_errors
            verification_info['verification_status'] = 'warning'
        
        return verification_info
    
    def _get_current_timestamp(self) -> str:
        """
        Get current timestamp in ISO format.
        
        Returns:
            Current timestamp string
        """
        from datetime import datetime
        return datetime.utcnow().isoformat() + 'Z' 