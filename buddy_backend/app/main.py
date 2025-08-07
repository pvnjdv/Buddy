# app/main.py (cleaned)
from fastapi import FastAPI
from app.core.config import settings
from app.core.database import engine
from app.models.user import User
from app.api.auth import router as auth_router
from app.api.user import router as user_router
from app.api.task import router as task_router
from app.api.chat import router as chat_router
from app.api.buddy import router as buddy_router
from app.api.notes import router as notes_router

app = FastAPI(title=settings.APP_NAME)

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
