from fastapi import APIRouter
from .chat import router as chat_router

# Main VSCode router
router = APIRouter(prefix="/vscode", tags=["vscode"])

# Include all vscode related routes
router.include_router(chat_router)