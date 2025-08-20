#!/usr/bin/env python3
"""
Test the new natural ChatGPT-like responses
"""

import asyncio
import sys
import os

# Add the project root to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.ai.buddy_ai import BuddyAI

async def test_natural_responses():
    """Test natural, ChatGPT-like responses"""
    print("🧪 Testing Natural ChatGPT-like Responses")
    print("=" * 50)
    
    buddy = BuddyAI()
    
    # Test cases that should be natural and conversational
    test_cases = [
        {
            "input": "hi",
            "expected": "Simple, natural greeting"
        },
        {
            "input": "What is Python?",
            "expected": "Natural explanation, not overwhelming"
        },
        {
            "input": "How do I learn programming?",
            "expected": "Conversational advice"
        },
        {
            "input": "Create a flow for building a website",
            "expected": "Complex flow generation"
        }
    ]
    
    for i, test in enumerate(test_cases, 1):
        print(f"\n{'='*20} Test {i} {'='*20}")
        print(f"User: {test['input']}")
        print(f"Expected: {test['expected']}")
        
        try:
            # Test the natural response
            response = await buddy.generate_ai_response(test['input'])
            
            print(f"\nResponse Type: {response.get('type')}")
            print(f"AI Mode: {response.get('ai_mode')}")
            
            # Show the actual response
            if response.get('type') == 'simple_response':
                print(f"Buddy: {response.get('content')}")
            elif response.get('type') == 'enhanced_response':
                content = response.get('content', {})
                print(f"Buddy: {content.get('direct_answer', 'No response')}")
            else:
                print(f"Buddy: {response}")
                
            print("✅ Natural and conversational" if response.get('ai_mode') in ['natural_conversation', 'natural_chatgpt'] else "⚠️  Check response style")
            
        except Exception as e:
            print(f"❌ Error: {e}")
    
    print(f"\n{'=' * 50}")
    print("🎉 Natural Response Testing Complete!")

if __name__ == "__main__":
    asyncio.run(test_natural_responses())
