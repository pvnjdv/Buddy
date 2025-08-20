#!/usr/bin/env python3

import asyncio
import sys
import os

# Add the app directory to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from ai.buddy_ai import BuddyAI

async def quick_test():
    buddy_ai = BuddyAI()
    
    user_context = {
        'user_id': 'test_user',
        'technical_stack': ['Python'],
        'preferences': {'style': 'clean'}
    }
    
    # Test the exact request
    response = await buddy_ai.generate_context_aware_response("generate code for calculator", user_context)
    
    print("Response type:", response.get('response_type'))
    print("Response:", response.get('response', 'No response'))
    
if __name__ == "__main__":
    asyncio.run(quick_test())
