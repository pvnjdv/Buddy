from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.core.config import settings
from app.ai.model_loader import load_ai_model

router = APIRouter()

class BuddyQuery(BaseModel):
    prompt: str

MODEL_NAME = settings.MODEL_NAME
MODEL_PATH = settings.MODEL_PATH

try:
    ai_model = load_ai_model(MODEL_NAME, MODEL_PATH)
except Exception as e:
    print(f"❌ Failed to load model: {e}")
    ai_model = None

@router.post("/buddy/ask")
async def ask_buddy(query: BuddyQuery):
    if ai_model is None:
        raise HTTPException(status_code=500, detail="AI model not loaded.")

    try:
        response = ai_model.generate_response(query.prompt)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating response: {e}")
