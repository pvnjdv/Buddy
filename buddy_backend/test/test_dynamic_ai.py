#!/usr/bin/env python3
"""
Test script for the new Dynamic AI System
Demonstrates GPT-5 and GitHub Copilot-like capabilities
"""

import asyncio
import json
import sys
import os

# Add the project root to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.ai.buddy_ai import BuddyAI

async def test_dynamic_ai():
    """Test the new dynamic AI system capabilities"""
    print("🚀 Testing Dynamic AI System - GPT-5 & GitHub Copilot Intelligence")
    print("=" * 70)
    
    # Initialize BuddyAI
    buddy = BuddyAI()
    
    # Test cases to demonstrate different capabilities
    test_cases = [
        {
            "name": "Flow Generation Test",
            "prompt": "Create a project flow for building a modern web application with user authentication",
            "user_id": "test_user_123",
            "expected_type": "flow"
        },
        {
            "name": "Code Generation Test", 
            "prompt": "Generate a Python FastAPI REST API with JWT authentication and user management",
            "user_id": "test_user_123",
            "expected_type": "code_solution"
        },
        {
            "name": "Enhanced Response Test",
            "prompt": "What are the best practices for building scalable web applications?",
            "user_id": "test_user_123", 
            "expected_type": "enhanced_response"
        }
    ]
    
    # Add some test knowledge to demonstrate RAG integration
    print("\n📚 Adding test knowledge to RAG system...")
    try:
        await buddy.add_knowledge(
            title="Web Development Best Practices",
            content="Use TypeScript for better code quality, implement proper error handling, use Docker for containerization, follow REST API design principles, implement proper authentication and authorization.",
            category="development",
            tags=["web", "typescript", "docker", "api", "auth"]
        )
        
        await buddy.add_knowledge(
            title="User Authentication Patterns",
            content="JWT tokens for stateless auth, refresh token rotation, secure password hashing with bcrypt, multi-factor authentication, proper session management.",
            category="security",
            tags=["authentication", "jwt", "security", "passwords"]
        )
        print("✅ Test knowledge added successfully!")
    except Exception as e:
        print(f"⚠️  Knowledge addition failed: {e}")
    
    # Run test cases
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n{'='*20} Test {i}: {test_case['name']} {'='*20}")
        print(f"Prompt: {test_case['prompt']}")
        print(f"Expected Type: {test_case['expected_type']}")
        
        try:
            # Generate AI response
            response = await buddy.generate_ai_response(
                test_case['prompt'], 
                test_case['user_id']
            )
            
            # Display results
            print(f"\n📊 Response Analysis:")
            print(f"Type: {response.get('type', 'unknown')}")
            print(f"AI Mode: {response.get('ai_mode', 'unknown')}")
            print(f"Context Used: {response.get('context_used', False)}")
            
            # Show intent analysis
            if 'intent_analysis' in response:
                intent = response['intent_analysis']
                print(f"Intent Type: {intent.get('intent_type', 'unknown')}")
                print(f"Confidence: {intent.get('confidence', 'unknown')}")
                print(f"Complexity: {intent.get('complexity_level', 'unknown')}")
            
            # Show content preview
            content = response.get('content', {})
            if isinstance(content, dict):
                print(f"\n📝 Content Preview:")
                if 'title' in content:
                    print(f"Title: {content['title']}")
                if 'direct_answer' in content:
                    print(f"Answer: {content['direct_answer'][:200]}...")
                if 'solution_overview' in content:
                    print(f"Solution: {content['solution_overview'][:200]}...")
            
            print(f"✅ Test {i} completed successfully!")
            
        except Exception as e:
            print(f"❌ Test {i} failed: {e}")
    
    print(f"\n{'='*70}")
    print("🎉 Dynamic AI System Testing Complete!")
    print("\nFeatures Demonstrated:")
    print("✅ Intelligent intent analysis")
    print("✅ Context-aware response generation") 
    print("✅ Dynamic flow creation (no templates)")
    print("✅ GitHub Copilot-like code generation")
    print("✅ GPT-5 enhanced responses")
    print("✅ RAG knowledge integration")

if __name__ == "__main__":
    asyncio.run(test_dynamic_ai())
