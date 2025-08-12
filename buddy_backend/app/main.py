# app/main.py (cleaned)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import engine
from app.models.user import User
from app.api.auth import router as auth_router
from app.api.user import router as user_router
from app.api.task import router as task_router
from app.api.chat import router as chat_router
from app.api.buddy import router as buddy_router
from app.api.notes import router as notes_router
from app.api.flows import router as flows_router
from app.api.alarms import router as alarms_router

app = FastAPI(title=settings.APP_NAME)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(User.metadata.create_all)

app.include_router(auth_router)
app.include_router(user_router)
app.include_router(task_router)
app.include_router(chat_router)
app.include_router(buddy_router)
app.include_router(notes_router)
app.include_router(flows_router)
app.include_router(alarms_router)
