#!/usr/bin/env python3
"""
Quick test for simple greeting detection
"""

import asyncio
import sys
import os

# Add the project root to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.ai.buddy_ai import BuddyAI

async def test_simple_greetings():
    """Test simple greeting detection and responses"""
    print("🧪 Testing Simple Greeting Detection")
    print("=" * 40)
    
    buddy = BuddyAI()
    
    # Test cases - simple greetings
    test_greetings = [
        "hi",
        "hello", 
        "hey",
        "Hi there!",
        "Hello, how are you?",
        "What's up?",
        "Good morning",
        "Hey buddy!"
    ]
    
    # Test cases - NOT simple greetings (should use full AI)
    complex_queries = [
        "Create a flow for building a web app",
        "How do I implement authentication in Python?",
        "Generate code for a REST API",
        "What are the best practices for React development?"
    ]
    
    print("Testing Simple Greetings (should be fast):")
    for greeting in test_greetings:
        print(f"\n📝 Input: '{greeting}'")
        
        # Check detection
        is_simple = buddy._is_simple_greeting(greeting)
        print(f"🤖 Detected as simple greeting: {is_simple}")
        
        if is_simple:
            # Test response generation
            response = await buddy._generate_simple_response(greeting)
            print(f"✅ Response type: {response.get('type')}")
            print(f"💬 Quick response: {response.get('content', {}).get('direct_answer', 'No response')[:100]}...")
    
    print(f"\n{'-' * 40}")
    print("Testing Complex Queries (should NOT be simple):")
    for query in complex_queries:
        print(f"\n📝 Input: '{query}'")
        is_simple = buddy._is_simple_greeting(query)
        print(f"🤖 Detected as simple greeting: {is_simple} ✅" if not is_simple else f"🤖 Detected as simple greeting: {is_simple} ❌")
    
    print(f"\n{'=' * 40}")
    print("🎉 Simple Greeting Test Complete!")

if __name__ == "__main__":
    asyncio.run(test_simple_greetings())
