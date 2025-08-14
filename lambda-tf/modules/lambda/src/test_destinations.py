#!/usr/bin/env python3
"""
Test script to verify destinations configuration.
This script can be used to check if destinations are properly configured
without triggering the Lambda function.
"""

import json
import sys
import os
from destinations import DestinationManager

def main():
    """
    Main function to test destinations configuration.
    """
    print("=== S3 Event Forwarder - Destination Verification ===")
    print()
    
    # Initialize destination manager
    try:
        destination_manager = DestinationManager()
        print("✓ Destination manager initialized successfully")
    except Exception as e:
        print(f"✗ Failed to initialize destination manager: {e}")
        sys.exit(1)
    
    print()
    
    # Get verification information
    try:
        verification_info = destination_manager.verify_destinations()
        print("✓ Destination verification completed")
    except Exception as e:
        print(f"✗ Failed to verify destinations: {e}")
        sys.exit(1)
    
    print()
    
    # Display verification results
    print("=== VERIFICATION RESULTS ===")
    print(f"Timestamp: {verification_info['timestamp']}")
    print(f"Destinations File: {verification_info['destinations_file']}")
    print(f"Total Destinations Loaded: {verification_info['total_destinations_loaded']}")
    print(f"Verification Status: {verification_info['verification_status'].upper()}")
    print()
    
    # Display destination types
    if verification_info['destination_types']:
        print("Destination Types:")
        for dest_type, count in verification_info['destination_types'].items():
            print(f"  - {dest_type.upper()}: {count}")
        print()
    
    # Display enabled destinations
    if verification_info['enabled_destinations']:
        print("Enabled Destinations:")
        for i, dest in enumerate(verification_info['enabled_destinations'], 1):
            print(f"  {i}. {dest['name']} ({dest['type'].upper()})")
            print(f"     ARN: {dest['arn']}")
            print(f"     Description: {dest['description']}")
            print()
    else:
        print("No enabled destinations found!")
        print()
    
    # Display validation errors if any
    if 'validation_errors' in verification_info:
        print("Validation Warnings:")
        for error in verification_info['validation_errors']:
            print(f"  ⚠ {error}")
        print()
    
    # Display detailed summary
    print("=== DETAILED SUMMARY ===")
    print(verification_info['destination_summary'])
    print()
    
    # Final status
    if verification_info['verification_status'] == 'success':
        print("✓ All destinations verified successfully!")
        sys.exit(0)
    else:
        print("⚠ Destinations verified with warnings. Please check the validation errors above.")
        sys.exit(1)

if __name__ == "__main__":
    main() 