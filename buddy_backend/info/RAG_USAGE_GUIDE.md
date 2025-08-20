# Buddy AI RAG System - Custom Knowledge Management

## Overview
The RAG (Retrieval-Augmented Generation) system allows you to feed custom information to Buddy AI for enhanced, personalized responses. The system uses vector-like similarity matching to find relevant context for user queries.

## 🚀 Quick Start

### 1. Adding Knowledge via API

**Endpoint:** `POST /api/knowledge/add`

```json
{
    "title": "My Coding Preferences",
    "content": "I prefer TypeScript over JavaScript. Always use strict mode. Use arrow functions for simple operations. Prefer async/await over promises.",
    "category": "personal",
    "tags": ["coding", "typescript", "preferences"],
    "metadata": {
        "source": "user_input",
        "importance": "high",
        "context_type": "instruction"
    }
}
```

### 2. Importing from JSON File

**Endpoint:** `POST /api/knowledge/import-file`

Use the sample file `sample_knowledge.json` or create your own:

```bash
curl -X POST "http://localhost:8000/api/knowledge/import-file" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"file_content": "..."}'  # JSON string content
```

### 3. Bulk Adding Knowledge

**Endpoint:** `POST /api/knowledge/bulk-add`

```json
[
    {
        "title": "Knowledge Entry 1",
        "content": "Content here...",
        "category": "work",
        "tags": ["tag1", "tag2"]
    },
    {
        "title": "Knowledge Entry 2",
        "content": "More content...",
        "category": "personal",
        "tags": ["tag3", "tag4"]
    }
]
```

## 📋 Knowledge Entry Format

### Required Fields
- **title**: Clear, descriptive title
- **content**: Detailed information content

### Optional Fields
- **category**: "personal", "work", "technical", "project", "general"
- **tags**: Array of relevant tags
- **metadata**: Additional metadata object

### Metadata Fields
```json
{
    "source": "user_input|file_import|system",
    "importance": "high|medium|low",
    "context_type": "fact|instruction|example|reference",
    "date_added": "2025-08-21T10:30:00",
    "custom_field": "any_value"
}
```

## 🔍 Using Knowledge

### Search Knowledge
**Endpoint:** `POST /api/knowledge/search`

```json
{
    "query": "typescript preferences",
    "category": "personal",
    "limit": 10
}
```

### List All Knowledge
**Endpoint:** `GET /api/knowledge/list?category=personal`

### Get Relevant Context (AI Use)
**Endpoint:** `GET /api/knowledge/context/{query}?limit=5`

## 📝 Knowledge Categories

### Recommended Categories:
- **personal**: Personal preferences, habits, schedule
- **work**: Work methodology, team processes
- **technical**: Technical guidelines, best practices
- **project**: Project-specific information
- **interests**: Hobbies, learning topics
- **general**: General information

## 🛠 Management Operations

### Update Knowledge
**Endpoint:** `PUT /api/knowledge/{knowledge_id}`

```json
{
    "content": "Updated content here...",
    "tags": ["updated", "tags"]
}
```

### Delete Knowledge
**Endpoint:** `DELETE /api/knowledge/{knowledge_id}`

### Get Statistics
**Endpoint:** `GET /api/knowledge/stats`

## 💡 Best Practices

### 1. Knowledge Writing Tips
- **Be Specific**: Write clear, actionable content
- **Use Context**: Include relevant context and examples
- **Update Regularly**: Keep information current
- **Tag Appropriately**: Use relevant tags for better retrieval

### 2. Content Organization
- **Categories**: Use consistent category names
- **Tags**: Include both general and specific tags
- **Metadata**: Add importance levels and context types

### 3. RAG Optimization
- **Relevant Content**: Add information you want the AI to remember
- **Clear Language**: Use clear, unambiguous language
- **Examples**: Include examples and use cases
- **Instructions**: Write actionable instructions

## 📚 Example Knowledge Entries

### 1. Personal Preference
```json
{
    "title": "Meeting Preferences",
    "content": "I prefer morning meetings (9-11 AM). Keep meetings under 30 minutes when possible. Always share agenda beforehand. Record action items.",
    "category": "personal",
    "tags": ["meetings", "schedule", "preferences"],
    "metadata": {
        "importance": "high",
        "context_type": "instruction"
    }
}
```

### 2. Technical Guideline
```json
{
    "title": "API Design Standards",
    "content": "Use RESTful conventions. Always validate input with Pydantic models. Return consistent error formats with HTTP status codes. Include proper documentation with examples.",
    "category": "technical",
    "tags": ["api", "rest", "standards", "backend"],
    "metadata": {
        "importance": "high",
        "context_type": "instruction"
    }
}
```

### 3. Project Information
```json
{
    "title": "Buddy App Database Schema",
    "content": "Main tables: users, flows, checkpoints, alarms, notes, personas. Uses SQLAlchemy ORM. PostgreSQL in production, SQLite for development. Async operations throughout.",
    "category": "project",
    "tags": ["buddy", "database", "schema", "sqlalchemy"],
    "metadata": {
        "importance": "high",
        "context_type": "reference"
    }
}
```

## 🔄 How RAG Works in Buddy

1. **Query Analysis**: When you ask Buddy something, it analyzes your question
2. **Context Retrieval**: Finds relevant knowledge entries using similarity matching
3. **Enhanced Response**: Combines retrieved context with AI knowledge
4. **Context Indicator**: Shows when custom knowledge was used

### Example Interaction:
**You**: "What's my preferred coding style for TypeScript?"

**Buddy**: "Based on your preferences, you prefer TypeScript over JavaScript with strict mode enabled. You like using arrow functions for simple operations and prefer async/await over promises. You also prefer meaningful variable names..."

*💡 Response enhanced with 1 relevant context(s) from knowledge base*

## 🚨 Important Notes

- **Privacy**: Knowledge is stored locally in SQLite database
- **User-Specific**: Each user's knowledge is isolated
- **Backup**: Consider backing up your knowledge base
- **Performance**: Large knowledge bases may slow retrieval
- **Updates**: Knowledge is automatically used in AI responses

## 📊 Monitoring

Check your knowledge base health:

```bash
# Get statistics
curl -X GET "http://localhost:8000/api/knowledge/stats" \
  -H "Authorization: Bearer YOUR_TOKEN"

# List categories
curl -X GET "http://localhost:8000/api/knowledge/list" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

This RAG system makes Buddy truly personalized by remembering your preferences, guidelines, and important information! 🧠✨
