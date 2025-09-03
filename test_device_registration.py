#!/usr/bin/env python3
"""
Test script for device auto-registration functionality
"""
import asyncio
import aiohttp
import json

# Test configuration
BASE_URL = "http://10.247.131.3:8000"  # Backend URL
TEST_MOBILE = "+1234567890"  # Replace with actual mobile for testing

async def test_auto_registration():
    """Test the auto-registration endpoint with different device types"""
    
    # Test data simulating Android device
    android_device_data = {
        "device_info": {
            "platform": "Android",
            "device_type": "mobile",
            "hostname": "SM-G950F",
            "model": "Galaxy S8",
            "brand": "Samsung",
            "manufacturer": "samsung",
            "android_version": "9",
            "sdk_version": 28,
            "architecture": "arm64",
            "ip_address": "192.168.1.100",
            "is_physical_device": True,
            "supported_abis": ["arm64-v8a", "armeabi-v7a", "armeabi"]
        },
        "capabilities": {
            "screen_share": True,
            "remote_control": False,
            "file_transfer": True,
            "command_execution": False,
            "input_control": False,
            "webcam": True,
            "microphone": True,
            "gps": True,
            "accelerometer": True,
            "push_notifications": True
        },
        "device_type": "mobile",
        "platform": "Android"
    }
    
    # Test data simulating Desktop device  
    desktop_device_data = {
        "device_info": {
            "platform": "Linux",
            "device_type": "desktop",
            "hostname": "linux-desktop",
            "ip_address": "192.168.1.101",
            "name": "Ubuntu Desktop",
            "pretty_name": "Ubuntu 22.04.3 LTS",
            "version_id": "22.04"
        },
        "capabilities": {
            "screen_share": True,
            "remote_control": True,
            "file_transfer": True,
            "command_execution": True,
            "input_control": True,
            "webcam": True,
            "microphone": True,
            "gps": False,
            "accelerometer": False,
            "push_notifications": True
        },
        "device_type": "desktop",
        "platform": "Linux"
    }

    async with aiohttp.ClientSession() as session:
        print("🔧 Testing Device Auto-Registration")
        print("=" * 50)
        
        # Step 1: Get OTP (simulated - you'd need actual authentication)
        print("⚠️  Note: This test requires valid authentication token")
        print("📱 Testing Android device registration...")
        
        # Test Android device registration
        headers = {
            'Content-Type': 'application/json',
            # 'Authorization': 'Bearer YOUR_TOKEN_HERE'  # Add actual token
        }
        
        try:
            async with session.post(
                f"{BASE_URL}/api/dock/auto-register",
                json=android_device_data,
                headers=headers
            ) as resp:
                if resp.status == 401:
                    print("❌ Authentication required - please add valid token")
                    return
                elif resp.status == 200:
                    data = await resp.json()
                    print("✅ Android device registration successful!")
                    print(f"   Device Name: {data['device']['name']}")
                    print(f"   Platform: {data['device']['platform']}")
                    print(f"   Device ID: {data['device_id']}")
                else:
                    text = await resp.text()
                    print(f"❌ Android registration failed: {resp.status}")
                    print(f"   Response: {text}")
        except Exception as e:
            print(f"❌ Connection error: {e}")
            
        print("\n🖥️  Testing Desktop device registration...")
        
        # Test Desktop device registration
        try:
            async with session.post(
                f"{BASE_URL}/api/dock/auto-register",
                json=desktop_device_data,
                headers=headers
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    print("✅ Desktop device registration successful!")
                    print(f"   Device Name: {data['device']['name']}")
                    print(f"   Platform: {data['device']['platform']}")
                    print(f"   Device ID: {data['device_id']}")
                else:
                    text = await resp.text()
                    print(f"❌ Desktop registration failed: {resp.status}")
                    print(f"   Response: {text}")
        except Exception as e:
            print(f"❌ Connection error: {e}")
            
        print("\n📋 Testing server-side device detection (no payload)...")
        
        # Test server-side detection (empty payload)
        try:
            async with session.post(
                f"{BASE_URL}/api/dock/auto-register",
                json={},
                headers=headers
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    print("✅ Server-side detection successful!")
                    print(f"   Device Name: {data['device']['name']}")
                    print(f"   Platform: {data['device']['platform']}")
                else:
                    text = await resp.text()
                    print(f"❌ Server-side detection failed: {resp.status}")
                    print(f"   Response: {text}")
        except Exception as e:
            print(f"❌ Connection error: {e}")

if __name__ == "__main__":
    print("🧪 Buddy Device Registration Test")
    print(f"Backend URL: {BASE_URL}")
    print("Make sure the backend server is running...")
    
    # Run the test
    asyncio.run(test_auto_registration())
