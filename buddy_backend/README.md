# Buddy Backend - Python API Server

**The FastAPI backend server for Buddy AI**

This Python backend provides the API server, database management, and cloud AI integration for Buddy AI.

## 🚀 Features

- **⚡ High-Performance API**: FastAPI with async/await support
- **🤖 AI Integration**: Groq, OpenAI, and custom AI model support
- **💾 Database Management**: SQLAlchemy with PostgreSQL/SQLite
- **🔐 Authentication**: JWT-based secure authentication
- **📡 Real-Time**: WebSocket support for live collaboration
- **🔧 Background Tasks**: Celery integration for async processing

## 📋 Requirements

- **Python**: 3.12+ recommended
- **Database**: PostgreSQL (recommended) or SQLite
- **Redis**: For caching and background tasks (optional)
- **API Keys**: Groq API key for cloud AI processing

## 🛠️ Installation & Setup

### 1. Clone Repository
```bash
git clone https://github.com/pvnjdv/Buddy.git
cd Buddy/buddy_backend
```

### 2. Create Virtual Environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Environment Configuration
Create a `.env` file (copy from `.env.example`):
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
```env
# Database
DATABASE_URL=postgresql://user:password@localhost/buddy
# or for SQLite:
# DATABASE_URL=sqlite:///./buddy.db

# AI Services
GROQ_API_KEY=your_groq_api_key_here
OPENAI_API_KEY=your_openai_api_key_here

# Security
SECRET_KEY=your_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Email (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password
```

### 5. Database Setup
```bash
# Create database tables
python -m app.core.init_db

# Or run with auto-create on startup (development)
uvicorn app.main:app --reload
```

### 6. Start Server
```bash
# Development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production server
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

## 📁 Project Structure

```
buddy_backend/
├── app/
│   ├── api/              # API endpoints
│   │   ├── auth.py       # Authentication
│   │   ├── buddy.py      # AI chat endpoints
│   │   ├── flows.py      # Project management
│   │   ├── dock.py       # Device control
│   │   └── ...
│   ├── core/             # Core configuration
│   │   ├── config.py     # App settings
│   │   ├── database.py   # Database setup
│   │   └── security.py   # Authentication logic
│   ├── models/           # Database models
│   │   ├── user.py       # User model
│   │   ├── message.py    # Chat messages
│   │   └── ...
│   ├── schemas/          # Pydantic schemas
│   ├── services/         # Business logic
│   │   ├── ai_service.py # AI processing
│   │   └── ...
│   ├── crud/             # Database operations
│   └── main.py           # FastAPI app
├── requirements.txt      # Python dependencies
├── .env.example         # Environment template
└── Procfile             # Deployment config
```

## 🔗 API Endpoints

### Authentication
- `POST /auth/login` - User login
- `POST /auth/register` - User registration
- `POST /auth/refresh` - Refresh access token
- `GET /auth/me` - Get current user profile

### AI Chat
- `POST /buddy/chat` - Send message to AI
- `GET /buddy/history` - Get chat history
- `POST /buddy/personas` - Create AI persona
- `GET /buddy/personas` - List AI personas

### Project Management
- `POST /flows` - Create new project flow
- `GET /flows` - List user flows
- `PUT /flows/{id}` - Update flow
- `DELETE /flows/{id}` - Delete flow

### Device Control
- `GET /dock/devices` - List connected devices
- `POST /dock/command` - Send device command
- `GET /dock/status` - Get device status

### Collaboration
- `POST /collaboration/workspaces` - Create workspace
- `GET /collaboration/workspaces` - List workspaces
- `WebSocket /ws/{workspace_id}` - Real-time collaboration

## 🤖 AI Integration

### Supported AI Providers
- **Groq**: High-performance inference (recommended)
- **OpenAI**: GPT models for advanced capabilities
- **Custom Models**: Plugin system for custom AI integration

### AI Service Configuration
```python
# app/services/ai_service.py
class AIService:
    def __init__(self):
        self.groq_client = GroqClient(api_key=settings.GROQ_API_KEY)
        self.openai_client = OpenAIClient(api_key=settings.OPENAI_API_KEY)
    
    async def generate_response(self, prompt: str, provider: str = "groq"):
        if provider == "groq":
            return await self.groq_client.chat_completion(prompt)
        elif provider == "openai":
            return await self.openai_client.chat_completion(prompt)
```

## 💾 Database Models

### User Management
```python
class User(Base):
    id: UUID
    email: str
    password_hash: str
    name: str
    profession: str
    created_at: datetime
```

### Chat Messages
```python
class BuddyFlowMessage(Base):
    id: UUID
    user_id: UUID
    content: str
    is_ai_response: bool
    session_id: str
    created_at: datetime
```

### Project Flows
```python
class ProjectFlow(Base):
    id: UUID
    user_id: UUID
    title: str
    description: str
    status: FlowStatus
    difficulty: FlowDifficulty
    checkpoints: List[FlowCheckpoint]
```

## 🔐 Security Features

### Authentication
- JWT token-based authentication
- Secure password hashing with bcrypt
- Token refresh mechanism
- Rate limiting for API endpoints

### Data Protection
- SQL injection prevention with SQLAlchemy
- Input validation with Pydantic
- CORS configuration for secure cross-origin requests
- Request logging and monitoring

## 🧪 Testing

```bash
# Run all tests
pytest

# Run specific test file
pytest tests/test_auth.py

# Run with coverage
pytest --cov=app tests/
```

### Test Structure
```
tests/
├── conftest.py          # Test configuration
├── test_auth.py         # Authentication tests
├── test_buddy.py        # AI chat tests
├── test_flows.py        # Flow management tests
└── ...
```

## 📊 Monitoring & Logging

### Logging Configuration
```python
import logging

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)
```

### Health Checks
- `GET /health` - Basic health check
- `GET /health/db` - Database connectivity
- `GET /health/ai` - AI service status

## 🚀 Deployment

### Docker Deployment
```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Environment Variables
Production deployment requires:
- `DATABASE_URL`: Production database connection
- `SECRET_KEY`: Secure random key for JWT
- `GROQ_API_KEY`: AI service API key
- `ALLOWED_ORIGINS`: Frontend domain(s)

### Database Migration
```bash
# Create migration
alembic revision --autogenerate -m "Add new feature"

# Apply migration
alembic upgrade head
```

## 🤝 Contributing

### Development Setup
1. Fork and clone the repository
2. Create virtual environment and install dependencies
3. Configure local environment variables
4. Run tests to ensure everything works
5. Make changes and submit pull request

### Code Style
- Follow PEP 8 Python style guide
- Use type hints for all functions
- Write docstrings for public methods
- Maintain test coverage above 80%

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**For complete documentation**, see the main [README](../README.md) and [API documentation](http://localhost:8000/docs) when running the server.