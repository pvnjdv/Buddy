#!/usr/bin/env python3
"""
Test script for calculator code generation
This tests whether "generate code for calculator" works properly now
"""

import asyncio
import sys
import os

# Add the app directory to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from ai.buddy_ai import BuddyAI

async def test_calculator_generation():
    """Test calculator code generation functionality"""
    
    print("Testing Calculator Code Generation...")
    print("=" * 50)
    
    try:
        # Initialize the AI system
        buddy_ai = BuddyAI()
        print("✅ BuddyAI initialized successfully")
        
        # Test the specific request that was failing
        test_request = "generate code for calculator"
        print(f"\nTesting request: '{test_request}'")
        
        # Mock user context (similar to what the API would provide)
        user_context = {
            'user_id': 'test_user',
            'technical_stack': ['Python', 'JavaScript'],
            'preferences': {'style': 'clean and readable'}
        }
        
        # Generate response using the natural ChatGPT-style system
        response = await buddy_ai.generate_context_aware_response(test_request, user_context)
        
        print("\n" + "="*50)
        print("RESPONSE:")
        print("="*50)
        print(f"Response type: {response.get('response_type', 'unknown')}")
        print(f"Response: {response.get('response', 'No response')}")
        
        # Check if we got a proper code solution
        if response.get('response_type') == 'code_solution':
            print("\n✅ SUCCESS: Code generation detected and executed!")
            solution = response.get('response', {})
            
            if isinstance(solution, dict):
                print(f"Solution overview: {solution.get('solution_overview', 'N/A')}")
                print(f"Primary language: {solution.get('primary_language', 'N/A')}")
                if 'complete_code' in solution:
                    print(f"Code provided: YES ({len(solution['complete_code'])} characters)")
                    print("Code preview:")
                    print("-" * 30)
                    print(solution['complete_code'][:200] + "..." if len(solution['complete_code']) > 200 else solution['complete_code'])
                    print("-" * 30)
                else:
                    print("Code provided: NO")
            else:
                print(f"Solution data type: {type(solution)}")
                print(f"Solution content: {solution}")
                
        elif response.get('response') == 'none':
            print("\n❌ FAILED: Still getting 'none' response")
            print("The code generation detection is not working properly")
            
        else:
            print(f"\n⚠️  UNEXPECTED: Got response type '{response.get('response_type')}' instead of 'code_solution'")
            print(f"Response: {response.get('response')}")
            
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("Calculator Code Generation Test")
    print("This tests the fix for the 'none' response issue")
    print()
    
    asyncio.run(test_calculator_generation())
