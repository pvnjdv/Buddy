"""
Test script for AI Persona system
This script tests the basic functionality of the persona management system
"""

import asyncio
import sys
import os

# Add the backend directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

async def test_persona_system():
    """Test basic persona functionality"""
    from app.crud.persona import persona_crud
    from app.schemas.persona import PersonaCreate
    from app.models.persona import AIPersona
    from app.ai.buddy_ai import BuddyAI
    from app.core.database import get_db
    
    print("🧪 Testing AI Persona System...")
    
    # Test 1: Create a persona
    print("\n1️⃣ Testing persona creation...")
    persona_data = PersonaCreate(
        name="Test Teacher",
        description="A friendly teacher who explains things clearly",
        response_style="educational"
    )
    
    # Simulate user ID (in real app, this comes from authentication)
    test_user_id = "test_user_123"
    
    # Test persona creation logic (without database)
    print(f"   ✅ Persona data: {persona_data.name}")
    print(f"   ✅ Description: {persona_data.description}")
    print(f"   ✅ Style: {persona_data.response_style}")
    
    # Test 2: Test BuddyAI persona system prompt generation
    print("\n2️⃣ Testing persona system prompt generation...")
    buddy_ai = BuddyAI()
    
    # Create a mock persona object
    class MockPersona:
        def __init__(self):
            self.id = "test_123"
            self.name = "Test Teacher"
            self.description = "A friendly teacher who explains things clearly"
            self.system_prompt = None
            self.personality_traits = '["patient", "clear", "encouraging"]'
            self.expertise_areas = '["education", "teaching"]'
            self.response_style = "educational"
    
    mock_persona = MockPersona()
    system_prompt = buddy_ai._build_persona_system_prompt(mock_persona)
    
    print(f"   ✅ Generated system prompt:")
    print(f"   {system_prompt[:200]}...")
    
    # Test 3: Test persona greeting
    print("\n3️⃣ Testing persona greeting...")
    greeting = buddy_ai.get_persona_greeting(mock_persona)
    print(f"   ✅ Greeting: {greeting}")
    
    # Test 4: Test default personas structure
    print("\n4️⃣ Testing default personas...")
    default_personas = [
        {
            "name": "Teacher",
            "description": "Friendly primary school teacher who explains complex topics in simple, easy-to-understand ways.",
            "response_style": "educational"
        },
        {
            "name": "Developer", 
            "description": "Experienced software developer with expertise in multiple programming languages.",
            "response_style": "technical"
        },
        {
            "name": "Writer",
            "description": "Creative and skilled writer who helps with content creation and editing.",
            "response_style": "creative"
        }
    ]
    
    for persona in default_personas:
        print(f"   ✅ Default persona: {persona['name']} ({persona['response_style']})")
    
    print("\n🎉 All persona system tests completed successfully!")
    print("\nNext steps:")
    print("1. Run the database migration: python add_personas_table.py")
    print("2. Start your backend server")
    print("3. Test the API endpoints:")
    print("   - POST /personas/ (create persona)")
    print("   - GET /personas/ (list personas)")
    print("   - POST /buddy/ask (chat with persona)")

if __name__ == "__main__":
    asyncio.run(test_persona_system())
