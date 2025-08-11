#!/usr/bin/env python3
"""
Test OTP Email Functionality

This script tests if OTP emails are working correctly.
"""

import sys
import os
import requests
import json

# Add the app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'app'))

def test_otp_request():
    """Test OTP request via API"""
    print("🧪 Testing OTP Request...")
    
    # Test with a sample mobile number
    test_mobile = "+91-9876543210"
    
    try:
        # Make API request
        url = "http://localhost:8000/auth/request-otp"
        payload = {"mobile_number": test_mobile}
        
        response = requests.post(url, json=payload)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ API Request successful!")
            print(f"📱 Mobile: {result.get('mobile_number')}")
            print(f"📧 Email sent: {result.get('email_sent')}")
            print(f"💬 Message: {result.get('message')}")
            print(f"\n📧 Check your email: p8975306526@gmail.com")
        else:
            print(f"❌ API Request failed: {response.status_code}")
            print(f"Response: {response.text}")
    
    except requests.exceptions.ConnectionError:
        print("❌ Connection failed. Is the backend server running?")
        print("💡 Start server with: python -m uvicorn app.main:app --reload")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    print("🚀 Buddy App OTP Email Test")
    print("=" * 40)
    test_otp_request()
