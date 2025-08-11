#!/bin/bash

# Script to update the API base IP address for Flutter app
# Usage: ./update_ip.sh <new_ip_address>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <new_ip_address>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

NEW_IP=$1
CONFIG_FILE="buddy_app/lib/config/api_config.dart"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Get current IP from config file
CURRENT_IP=$(grep '_baseIp.*=' "$CONFIG_FILE" | sed "s/.*'\(.*\)'.*/\1/")

echo "Current IP: $CURRENT_IP"
echo "New IP: $NEW_IP"

# Update the IP address in the config file
sed -i "s/static const String _baseIp = '$CURRENT_IP';/static const String _baseIp = '$NEW_IP';/" "$CONFIG_FILE"

echo "✓ Updated API configuration"
echo "💡 Don't forget to hot reload your Flutter app (press 'r' in the Flutter terminal)"
echo "🌐 New base URL will be: http://$NEW_IP:8000"
