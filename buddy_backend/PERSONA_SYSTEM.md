# AI Persona System - Backend Implementation

## Overview

The AI Persona system allows users to create and manage multiple custom AI personalities that can be used for different types of interactions. Each persona has its own personality traits, expertise areas, response style, and behavior patterns.

## Features

### ✨ Core Features
- **Multiple Custom Personas**: Users can create unlimited custom AI personalities
- **Default Personas**: Pre-built Teacher, Developer, and Writer personas
- **Persona Switching**: Easy switching between different AI personalities
- **Persistent Storage**: All personas are saved in the database
- **Active Persona Management**: Set one persona as active for automatic use

### 🎯 Persona Attributes
- **Name**: Custom name for the AI persona
- **Description**: Detailed description of personality and behavior
- **System Prompt**: Custom system prompt (auto-generated if not provided)
- **Personality Traits**: JSON array of personality characteristics
- **Expertise Areas**: JSON array of areas of expertise
- **Response Style**: Communication style (formal, casual, technical, educational, creative, conversational)

## API Endpoints

### Persona Management

#### Create Persona
```http
POST /personas/
Content-Type: application/json

{
    "name": "Math Tutor",
    "description": "Patient math teacher specializing in algebra and calculus",
    "response_style": "educational",
    "personality_traits": "[\"patient\", \"encouraging\", \"precise\"]",
    "expertise_areas": "[\"mathematics\", \"algebra\", \"calculus\"]"
}
```

#### List All User Personas
```http
GET /personas/
```
Returns:
```json
{
    "personas": [
        {
            "id": "uuid-123",
            "name": "Math Tutor",
            "description": "Patient math teacher...",
            "is_active": true,
            "created_at": "2024-01-01T00:00:00Z"
        }
    ],
    "active_persona": {
        "id": "uuid-123",
        "name": "Math Tutor"
    },
    "total_count": 1
}
```

#### Get Active Persona
```http
GET /personas/active
```

#### Activate Persona
```http
PUT /personas/{persona_id}/activate
```

#### Deactivate All Personas
```http
PUT /personas/deactivate
```

#### Update Persona
```http
PUT /personas/{persona_id}
Content-Type: application/json

{
    "description": "Updated description",
    "response_style": "casual"
}
```

#### Delete Persona
```http
DELETE /personas/{persona_id}
```

#### Initialize Default Personas
```http
POST /personas/initialize-defaults
```
Creates Teacher, Developer, and Writer personas for new users.

### Chat with Personas

#### Chat with Specific Persona
```http
POST /buddy/ask
Content-Type: application/json

{
    "prompt": "Explain calculus to me",
    "persona_id": "uuid-123",
    "chat_history": [
        {"role": "user", "content": "Hello"},
        {"role": "assistant", "content": "Hi! I'm your Math Tutor..."}
    ]
}
```

#### Chat with Active Persona
```http
POST /buddy/ask
Content-Type: application/json

{
    "prompt": "Help me with my project",
    "chat_history": []
}
```
*Uses the currently active persona automatically*

## Database Schema

### AIPersona Table
```sql
CREATE TABLE ai_personas (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    system_prompt TEXT,
    personality_traits TEXT,  -- JSON string
    expertise_areas TEXT,     -- JSON string
    response_style VARCHAR(50),
    is_active BOOLEAN DEFAULT FALSE,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

## Setup Instructions

### 1. Database Migration
```bash
cd buddy_backend
python add_personas_table.py
```

### 2. Test the System
```bash
python test_persona_system.py
```

### 3. Start the Server
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Initialize Default Personas (Optional)
```http
POST /personas/initialize-defaults
Authorization: Bearer <your-token>
```

## Usage Examples

### Creating a Custom Teacher Persona
```json
{
    "name": "Elementary Teacher",
    "description": "Patient elementary school teacher who explains complex concepts in simple terms using fun examples and analogies",
    "response_style": "educational",
    "personality_traits": "[\"patient\", \"encouraging\", \"creative\", \"fun\"]",
    "expertise_areas": "[\"elementary education\", \"child psychology\", \"creative teaching\"]"
}
```

### Creating a Technical Expert Persona
```json
{
    "name": "Senior Developer",
    "description": "Experienced full-stack developer with 10+ years in web development, specializing in React, Node.js, and cloud architecture",
    "response_style": "technical",
    "personality_traits": "[\"analytical\", \"precise\", \"helpful\", \"methodical\"]",
    "expertise_areas": "[\"javascript\", \"react\", \"nodejs\", \"aws\", \"docker\"]"
}
```

### Creating a Creative Writer Persona
```json
{
    "name": "Creative Storyteller",
    "description": "Imaginative writer who loves crafting engaging stories, developing characters, and helping others express their creativity through words",
    "response_style": "creative",
    "personality_traits": "[\"imaginative\", \"inspiring\", \"eloquent\", \"passionate\"]",
    "expertise_areas": "[\"creative writing\", \"storytelling\", \"character development\", \"poetry\"]"
}
```

## Architecture

### Components
- **Models**: `app/models/persona.py` - Database model for personas
- **Schemas**: `app/schemas/persona.py` - Pydantic schemas for API validation
- **CRUD**: `app/crud/persona.py` - Database operations
- **API**: `app/api/personas.py` - REST API endpoints
- **AI Integration**: `app/ai/buddy_ai.py` - Persona-enhanced AI responses

### AI Integration
The persona system integrates with the existing BuddyAI class:

1. **System Prompt Generation**: Automatically builds system prompts from persona attributes
2. **Response Enhancement**: Ensures responses match the persona's style and expertise
3. **Context Awareness**: Maintains persona consistency throughout conversations
4. **Fallback Handling**: Gracefully falls back to default Buddy if persona fails

## Default Personas

### 📚 Teacher
- **Style**: Educational, patient, encouraging
- **Expertise**: Education, teaching, learning techniques
- **Best For**: Learning new concepts, study help, explanations

### 💻 Developer  
- **Style**: Technical, precise, solution-oriented
- **Expertise**: Programming, software development, technology
- **Best For**: Coding help, technical problems, software guidance

### ✍️ Writer
- **Style**: Creative, eloquent, inspiring
- **Expertise**: Writing, content creation, communication
- **Best For**: Writing assistance, content creation, editing help

## Security & Validation

- **User Isolation**: Users can only access their own personas
- **Input Validation**: All inputs validated using Pydantic schemas
- **SQL Injection Protection**: Uses SQLAlchemy ORM with parameterized queries
- **Error Handling**: Comprehensive error handling with meaningful messages
- **Authentication**: All endpoints require valid JWT authentication

## Performance Considerations

- **Database Indexing**: Indexed on user_id and is_active for fast lookups
- **Async Operations**: All database operations are asynchronous
- **Caching**: Active persona cached per request to minimize database calls
- **Efficient Queries**: Optimized queries to reduce database load

## Troubleshooting

### Common Issues

1. **"Persona not found" error**
   - Ensure persona_id belongs to the authenticated user
   - Check that persona hasn't been deleted

2. **"No active persona" response**
   - User hasn't set any persona as active
   - Use `/personas/{id}/activate` to set active persona

3. **System prompt not working**
   - Check persona.system_prompt field in database
   - Verify AI client is receiving the enhanced prompt

4. **Database connection errors**
   - Ensure database migration has been run
   - Check database connection settings

## Future Enhancements

- **Persona Templates**: Pre-made persona templates for common use cases
- **Persona Sharing**: Allow users to share personas with others
- **Learning Adaptation**: Personas that learn and adapt from user interactions
- **Voice & Personality**: Integration with text-to-speech for voice personas
- **Persona Analytics**: Track usage and effectiveness of different personas
