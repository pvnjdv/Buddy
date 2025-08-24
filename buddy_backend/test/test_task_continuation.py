#!/usr/bin/env python3
"""
Test script for task continuation functionality in the Buddy backend.
This script tests the new BuddyQuery fields: is_task_continuation, recent_context, session_id
"""

import requests
import json
import uuid

# Backend URL - adjust if needed
BASE_URL = "http://localhost:8000"

def test_task_continuation():
    """Test the task continuation functionality"""
    
    # Generate a session ID for testing
    session_id = str(uuid.uuid4())
    
    # Test data for task continuation
    test_data = {
        "prompt": "Add a feature to validate email addresses",
        "chat_history": [
            {"role": "user", "content": "Create a simple user registration form"},
            {"role": "assistant", "content": "I'll create a user registration form with name, email, and password fields..."}
        ],
        "is_flow_request": False,
        "persona_id": None,
        "is_task_continuation": True,
        "recent_context": "User requested a user registration form with name, email, and password fields. I created a basic HTML form with input validation.",
        "session_id": session_id
    }
    
    try:
        print("🧪 Testing Task Continuation Endpoint...")
        print(f"📋 Session ID: {session_id}")
        print(f"🔄 Task Continuation: {test_data['is_task_continuation']}")
        print(f"📝 Recent Context: {test_data['recent_context'][:50]}...")
        
        # Send request to the backend
        response = requests.post(
            f"{BASE_URL}/buddy/ask",
            json=test_data,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        print(f"\n📡 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Task Continuation Test PASSED")
            print(f"🤖 Response: {result.get('response', 'No response')[:100]}...")
            print(f"🎯 Intent Analysis: {result.get('intent_analysis', 'N/A')}")
            print(f"🧠 Thinking Summary: {result.get('thinking_summary', 'N/A')}")
        else:
            print("❌ Task Continuation Test FAILED")
            print(f"Error: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection Error: Backend server is not running")
        print("💡 Please start the backend server first: python -m uvicorn app.main:app --reload")
    except Exception as e:
        print(f"❌ Test Error: {str(e)}")

def test_regular_request():
    """Test regular request without task continuation"""
    
    test_data = {
        "prompt": "Create a simple calculator app",
        "chat_history": [],
        "is_flow_request": False,
        "persona_id": None,
        "is_task_continuation": False,
        "recent_context": None,
        "session_id": str(uuid.uuid4())
    }
    
    try:
        print("\n🧪 Testing Regular Request Endpoint...")
        
        response = requests.post(
            f"{BASE_URL}/buddy/ask",
            json=test_data,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        print(f"📡 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Regular Request Test PASSED")
            print(f"🤖 Response: {result.get('response', 'No response')[:100]}...")
        else:
            print("❌ Regular Request Test FAILED")
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"❌ Test Error: {str(e)}")

if __name__ == "__main__":
    print("🚀 Starting Backend Task Continuation Tests")
    print("="*50)
    
    test_task_continuation()
    test_regular_request()
    
    print("\n" + "="*50)
    print("✨ Test completed!")
