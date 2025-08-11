#!/usr/bin/env python3
"""
Configuration module for S3 Event Forwarder

Handles loading and managing destination configurations for SQS queues and SNS topics.
"""

import json
import os
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger()

# Default configuration
DEFAULT_CONFIG = {
    "sqs_queues": [
        {
            "name": "s3-events-processing-queue",
            "url": "https://sqs.us-east-1.amazonaws.com/123456789012/s3-events-processing-queue",
            "arn": "arn:aws:sqs:us-east-1:123456789012:s3-events-processing-queue",
            "enabled": True
        }
    ],
    "sns_topics": [
        {
            "name": "s3-events-notifications",
            "arn": "arn:aws:sns:us-east-1:123456789012:s3-events-notifications",
            "enabled": True
        }
    ]
}

def get_destinations_config() -> Dict[str, Any]:
    """Get destinations configuration with fallback to defaults."""
    try:
        # Try environment variables first
        config = _load_from_env()
        if config:
            logger.info("Loaded configuration from environment variables")
            return _ensure_structure(config)
        
        # Try config file
        config = _load_from_file()
        if config:
            logger.info("Loaded configuration from config file")
            return _ensure_structure(config)
        
        # Use default configuration
        logger.info("Using default configuration")
        return DEFAULT_CONFIG
        
    except Exception as e:
        logger.error(f"Error loading configuration: {str(e)}")
        return DEFAULT_CONFIG

def _ensure_structure(config: Dict[str, Any]) -> Dict[str, Any]:
    """Ensure configuration has required structure with empty arrays if missing."""
    config = config.copy()
    config.setdefault('sqs_queues', [])
    config.setdefault('sns_topics', [])
    
    # Ensure arrays are lists
    if not isinstance(config['sqs_queues'], list):
        config['sqs_queues'] = []
    if not isinstance(config['sns_topics'], list):
        config['sns_topics'] = []
    
    return config

def _load_from_env() -> Optional[Dict[str, Any]]:
    """Load configuration from environment variables."""
    try:
        # Full configuration
        if 'S3_FORWARDER_CONFIG' in os.environ:
            return json.loads(os.environ['S3_FORWARDER_CONFIG'])
        
        # Individual configurations
        config = {}
        if 'S3_FORWARDER_SQS_QUEUES' in os.environ:
            config['sqs_queues'] = json.loads(os.environ['S3_FORWARDER_SQS_QUEUES'])
        if 'S3_FORWARDER_SNS_TOPICS' in os.environ:
            config['sns_topics'] = json.loads(os.environ['S3_FORWARDER_SNS_TOPICS'])
        
        return config if config else None
        
    except (json.JSONDecodeError, Exception) as e:
        logger.error(f"Error loading from environment: {str(e)}")
        return None

def _load_from_file() -> Optional[Dict[str, Any]]:
    """Load configuration from config file."""
    config_files = ['/tmp/s3-forwarder-config.json', './config.json', './s3-forwarder-config.json']
    
    for config_file in config_files:
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    return json.load(f)
        except (json.JSONDecodeError, Exception) as e:
            logger.error(f"Error loading from {config_file}: {str(e)}")
    
    return None 