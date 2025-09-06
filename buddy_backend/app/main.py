# app/main.py (cleaned)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import engine, Base
from app.models import user as user_models  # noqa: F401 register models
from app.models import message as message_models  # noqa: F401 register models
from app.models import persona as persona_models  # noqa: F401 register models
from app.models import dock as dock_models  # noqa: F401 register models
from app.api.auth import router as auth_router
from app.api.user import router as user_router
from app.api.task import router as task_router
from app.api.chat import router as chat_router
from app.api.buddy import router as buddy_router
from app.api.notes import router as notes_router
from app.api.flows import router as flows_router
from app.api.alarms import router as alarms_router
from app.api.personas import router as personas_router
from app.api.github import router as github_router
from app.api.system import router as system_router
from app.api.knowledge import router as knowledge_router
from app.api.dock import router as dock_router
from app.api.code_execution import router as code_execution_router

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
        await conn.run_sync(Base.metadata.create_all)

app.include_router(auth_router)
app.include_router(user_router)
app.include_router(task_router)
app.include_router(chat_router)
app.include_router(buddy_router)
app.include_router(notes_router)
app.include_router(flows_router)
app.include_router(alarms_router)
app.include_router(personas_router)
app.include_router(github_router, prefix="/api/github", tags=["github"])
app.include_router(system_router, prefix="/api/system", tags=["system"])
app.include_router(knowledge_router, prefix="/api/knowledge", tags=["knowledge"])
app.include_router(dock_router, prefix="/api/dock", tags=["dock"])
app.include_router(code_execution_router, prefix="/api/code", tags=["code-execution"])
