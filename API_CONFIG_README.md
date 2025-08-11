# API Configuration Management

## Overview
All API endpoints for the Flutter app are now centrally managed through a single configuration file.

## Quick IP Address Change

### Method 1: Using the Script (Recommended)
```bash
# From the project root directory
./update_ip.sh <your_new_ip_address>

# Example:
./update_ip.sh 192.168.1.100
```

### Method 2: Manual Edit
Edit the file: `buddy_app/lib/config/api_config.dart`

Change this line:
```dart
static const String _baseIp = '10.247.131.3';  // Change this IP
```

## Finding Your IP Address

### On Linux/Mac:
```bash
# Get your current IP address
ip addr show | grep "inet " | grep -v "127.0.0.1"
# or
ifconfig | grep "inet " | grep -v "127.0.0.1"
```

### On Windows:
```cmd
ipconfig
```

## After Changing IP
1. Save the changes
2. In your Flutter terminal, press `r` for hot reload
3. Test the OTP functionality

## Configuration File Location
- **File**: `buddy_app/lib/config/api_config.dart`
- **Purpose**: Central management of all API endpoints
- **Benefits**: 
  - Change IP in one place only
  - Consistent URL management
  - Easy debugging with `ApiConfig.printConfig()`

## Troubleshooting
- Ensure your Android device and development machine are on the same network
- Check if port 8000 is accessible from your device
- Verify the backend server is running: `lsof -i :8000`
