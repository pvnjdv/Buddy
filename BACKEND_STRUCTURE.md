# Buddy Backend - Project Structure & Architecture

## 📁 **Complete Backend File Structure**

```
buddy_backend/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI application entry point
│   ├── dependencies.py         # Dependency injection functions
│   │
│   ├── api/                    # API endpoints and routes
│   │   ├── __init__.py
│   │   ├── auth.py            # Authentication endpoints (OTP, login)
│   │   ├── user.py            # User management endpoints
│   │   ├── chat.py            # Chat and messaging endpoints
│   │   ├── buddy.py           # AI chat and flow generation endpoints
│   │   ├── task.py            # Task management endpoints
│   │   ├── flows.py           # Project flow management endpoints
│   │   ├── notes.py           # Note-taking endpoints
│   │   ├── base.py            # Base API utilities
│   │   └── v1/                # API versioning directory
│   │
│   ├── core/                  # Core application configuration
│   │   ├── __init__.py
│   │   ├── config.py          # Application settings and environment variables
│   │   ├── database.py        # Database connection and session management
│   │   └── security.py        # Security utilities (JWT, password hashing)
│   │
│   ├── models/                # SQLAlchemy database models
│   │   ├── __init__.py
│   │   ├── user.py            # User model with authentication
│   │   ├── task.py            # Task and project management models
│   │   ├── message.py         # Chat message models
│   │   ├── flow.py            # Project flow and checkpoint models
│   │   └── llama/             # LLaMA-specific model configurations
│   │
│   ├── schemas/               # Pydantic models for request/response validation
│   │   ├── __init__.py
│   │   ├── user.py            # User-related schemas
│   │   ├── auth.py            # Authentication schemas
│   │   ├── chat.py            # Chat message schemas
│   │   ├── task.py            # Task management schemas
│   │   └── flow.py            # Flow and checkpoint schemas
│   │
│   ├── services/              # Business logic and external service integrations
│   │   ├── __init__.py
│   │   ├── auth_service.py    # Authentication business logic
│   │   ├── chat_service.py    # Chat and messaging services
│   │   ├── task_service.py    # Task management services
│   │   ├── flow_service.py    # Project flow generation services
│   │   └── email_service.py   # Email and notification services
│   │
│   ├── ai/                    # AI integration and model management
│   │   ├── __init__.py
│   │   ├── buddy_ai.py        # Main AI assistant logic
│   │   ├── flow_generator.py  # Project flow generation AI
│   │   ├── groq_client.py     # Groq API integration
│   │   ├── mistral_runner.py  # Mistral model integration
│   │   ├── model_loader.py    # Unified AI client for multiple providers
│   │   └── buddy_ai_backup.py # Backup AI implementation
│   │
│   └── crud/                  # Database CRUD operations
│       ├── __init__.py
│       ├── user.py            # User database operations
│       ├── task.py            # Task database operations
│       ├── chat.py            # Chat database operations
│       └── flow.py            # Flow database operations
│
├── buddy.db                   # SQLite database file
├── requirements.txt           # Python dependencies
├── Procfile                   # Heroku deployment configuration
├── email_config.txt          # Email service configuration
└── test_otp.py               # OTP testing script
```

## 🏗️ **Architecture Overview**

### **Framework & Technology Stack**
- **Framework**: FastAPI (async Python web framework)
- **Database**: SQLite with SQLAlchemy ORM (async)
- **Authentication**: JWT-based with OTP verification
- **AI Integration**: Multiple providers (Groq, Mistral, LLaMA)
- **Deployment**: Heroku-ready with Procfile

### **Key Dependencies**
```python
# Core Framework
fastapi==0.116.1
uvicorn==0.30.6

# Database & ORM
sqlalchemy==2.0.32
aiosqlite==0.21.0

# Authentication & Security
passlib==1.7.4
bcrypt==4.3.0
python-jose==3.3.0

# AI & ML
groq==0.31.0
llama_cpp_python==0.3.15

# Async & HTTP
httpx==0.28.1
aiofiles==23.2.1

# Email & Notifications
email_validator==2.2.0
```

## 📊 **Database Models**

### **Core Models**
1. **User Model** (`models/user.py`)
   - User authentication and profile management
   - Mobile number, OTP verification, profile details

2. **Task Model** (`models/task.py`)
   - Task and project management
   - Status tracking, priority levels, deadlines

3. **Message Model** (`models/message.py`)
   - Chat messaging system
   - User-to-user communication, media support

4. **Flow Model** (`models/flow.py`)
   - Project flow management with AI generation
   - Checkpoints, progress tracking, difficulty levels

### **Model Relationships**
```python
# Key relationships
User -> Tasks (One-to-Many)
User -> Messages (One-to-Many)
User -> ProjectFlows (One-to-Many)
ProjectFlow -> FlowCheckpoints (One-to-Many)
ProjectFlow -> BuddyFlowMessages (One-to-Many)
```

## 🔗 **API Endpoints Structure**

### **Authentication Routes** (`/auth`)
```python
POST /auth/request-otp      # Request OTP for mobile number
POST /auth/verify-otp       # Verify OTP and get JWT token
POST /auth/refresh-token    # Refresh JWT token
```

### **User Management** (`/users`)
```python
GET  /users/me             # Get current user profile
PUT  /users/profile        # Update user profile
GET  /users/by-mobile      # Get user by mobile number
POST /users/details        # Create/update user details
```

### **Chat System** (`/chats`)
```python
GET  /chats/contacts       # Get user's chat contacts
GET  /chats/{contact_id}   # Get chat history with specific contact
POST /chats/send           # Send new message
GET  /chats/messages       # Get paginated messages
```

### **AI Assistant** (`/buddy`)
```python
POST /buddy/chat           # General AI chat interaction
POST /buddy/generate-flow  # Generate project flow using AI
POST /buddy/checkpoint-help # Get help for specific checkpoint
GET  /buddy/chat-history   # Get AI chat history
```

### **Project Flows** (`/flows`)
```python
GET  /flows                # Get user's project flows
POST /flows                # Create new project flow
GET  /flows/{flow_id}      # Get specific flow details
PUT  /flows/{flow_id}      # Update flow progress
DELETE /flows/{flow_id}    # Delete project flow
```

### **Task Management** (`/tasks`)
```python
GET  /tasks                # Get user's tasks
POST /tasks                # Create new task
PUT  /tasks/{task_id}      # Update task
DELETE /tasks/{task_id}    # Delete task
```

## 🤖 **AI Integration Architecture**

### **Multi-Provider AI System**
```python
# Unified AI Client (model_loader.py)
class UnifiedAIClient:
    - Groq API integration
    - Local LLaMA model support
    - Mistral API integration
    - Automatic provider fallback
```

### **AI Features**
1. **Buddy AI** (`ai/buddy_ai.py`)
   - Conversational AI with context awareness
   - Project flow generation from natural language
   - Checkpoint-specific assistance

2. **Flow Generator** (`ai/flow_generator.py`)
   - Automated project breakdown
   - Task timeline estimation
   - Resource and requirement suggestions

## 🔐 **Security Features**

### **Authentication Flow**
1. Mobile number validation
2. OTP generation and SMS delivery
3. JWT token creation with refresh mechanism
4. Role-based access control

### **Security Middleware**
- CORS configuration for Flutter app
- Request rate limiting
- Input validation with Pydantic
- SQL injection prevention with SQLAlchemy

## 📱 **Mobile App Integration**

### **API Communication**
- RESTful API design
- JSON request/response format
- Error handling with HTTP status codes
- Async request handling

### **Real-time Features**
- Chat messaging system
- AI response streaming simulation
- Contact synchronization
- Push notification ready

## 🚀 **Deployment Configuration**

### **Heroku Ready**
```python
# Procfile
web: uvicorn app.main:app --host=0.0.0.0 --port=${PORT:-8000}
```

### **Environment Variables**
```python
# .env configuration
DATABASE_URL=sqlite:///./buddy.db
SECRET_KEY=your-secret-key
GROQ_API_KEY=your-groq-key
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
EMAIL_USERNAME=your-email
EMAIL_PASSWORD=your-password
```

## 🎯 **Current Implementation Status**

### ✅ **Completed Features**
- Full authentication system with OTP
- Complete CRUD operations for all models
- AI integration with multiple providers
- Chat messaging system
- Project flow management
- Task management system
- SQLite database with async operations

### 🔄 **Areas for Enhancement**
- Redis for session management
- PostgreSQL for production database
- WebSocket for real-time chat
- File upload and storage system
- Push notification service
- API rate limiting
- Comprehensive logging system
- Unit and integration tests

## 📋 **Questions for ChatGPT Analysis**

1. **Architecture Review**: How can we improve the current architecture for better scalability?
2. **Security Enhancements**: What additional security measures should be implemented?
3. **Performance Optimization**: How can we optimize database queries and API response times?
4. **Code Organization**: Are there better ways to organize the codebase for maintainability?
5. **Testing Strategy**: What testing approach would be most effective for this architecture?
6. **Deployment**: What's the best deployment strategy for production?
7. **Monitoring**: What monitoring and logging should be implemented?
8. **API Design**: How can we improve the RESTful API design?

---

**Note**: This backend serves a Flutter mobile application with WhatsApp-like chat, ChatGPT-like AI assistant, and Google Keep-like note-taking features.
