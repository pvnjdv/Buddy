#!/usr/bin/env python3
"""
Debug code generation issue
"""

import asyncio
import sys
import os

# Add the project root to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.ai.buddy_ai import BuddyAI

async def debug_code_generation():
    """Debug why code generation returns 'none'"""
    print("🐛 Debugging Code Generation Issue")
    print("=" * 50)
    
    buddy = BuddyAI()
    
    test_prompt = "generate code for calculator"
    print(f"Testing prompt: '{test_prompt}'")
    
    try:
        print("\n1. Testing simple keyword detection...")
        code_keywords = ['generate code', 'write code', 'create code', 'code for', 'build app', 'make program', 'programming', 'script', 'function']
        is_code_request = any(keyword in test_prompt.lower() for keyword in code_keywords)
        print(f"   Is code request detected: {is_code_request}")
        
        print("\n2. Testing AI response generation...")
        response = await buddy.generate_ai_response(test_prompt)
        
        print(f"   Response type: {response.get('type')}")
        print(f"   AI mode: {response.get('ai_mode')}")
        print(f"   Content keys: {list(response.get('content', {}).keys())}")
        
        if response.get('type') == 'code_solution':
            content = response.get('content', {})
            print(f"   Solution overview: {content.get('solution_overview', 'NOT FOUND')}")
            print(f"   Has error: {'error' in content}")
            if 'error' in content:
                print(f"   Error: {content.get('error')}")
        
        print(f"\n3. Full response structure:")
        print(f"   {response}")
        
    except Exception as e:
        print(f"❌ Error during testing: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(debug_code_generation())
