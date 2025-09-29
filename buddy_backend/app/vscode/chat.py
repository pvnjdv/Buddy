from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional
from ..core.jwt import verify_token
from ..ai.buddy_ai import BuddyAI
from ..crud.user import get_user_by_mobile
from ..core.database import get_db
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter()
security = HTTPBearer()

# Initialize Buddy AI instance
buddy_ai = BuddyAI()

class VSCodeChatRequest(BaseModel):
    message: str
    context: Optional[dict] = None

class VSCodeChatResponse(BaseModel):
    response: str
    message_id: Optional[str] = None
    status: str = "success"

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
):
    """Get current user from JWT token"""
    try:
        payload = verify_token(credentials.credentials)
        if payload is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
            
        mobile_number = payload.get("sub")
        if mobile_number is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
        
        user = await get_user_by_mobile(db, mobile_number)
        if user is None:
            raise HTTPException(status_code=401, detail="User not found")
        
        return user
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")

@router.post("/chat", response_model=VSCodeChatResponse)
async def vscode_chat(
    request: VSCodeChatRequest,
    user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Handle chat requests from VS Code extension
    """
    try:
        # Get AI response using existing Buddy AI system
        user_id = str(user.id) if user else None
        
        # Use the same AI system as the main app
        ai_response = await buddy_ai.generate_ai_response(
            prompt=request.message,
            user_id=user_id,
            db_session=db,
            chat_history=[],  # Could be extended to maintain chat history
            sub_mode="standard"
        )
        
        # Extract response text from AI response
        response_text = "I'm here to help with your coding tasks!"
        
        if isinstance(ai_response, dict):
            if ai_response.get("type") == "simple_response":
                response_text = ai_response.get("content", response_text)
            elif ai_response.get("type") == "enhanced_response":
                content = ai_response.get("content", {})
                response_text = content.get("direct_answer", response_text)
            elif ai_response.get("type") == "code_solution":
                content = ai_response.get("content", {})
                if content.get("complete_code"):
                    response_text = f"Here's the code solution:\n\n```{content.get('primary_language', 'python')}\n{content.get('complete_code')}\n```\n\n{content.get('explanation', '')}"
                else:
                    response_text = content.get('solution_overview', response_text)
            elif ai_response.get("type") == "flow":
                content = ai_response.get("content", {})
                response_text = f"🚀 Flow: {content.get('title', 'Project Flow')}\n\n{content.get('description', 'Flow created successfully!')}"
            else:
                # Fallback for other response types
                if isinstance(ai_response.get("content"), str):
                    response_text = ai_response.get("content")
                else:
                    response_text = str(ai_response)
        elif isinstance(ai_response, str):
            response_text = ai_response
        
        return VSCodeChatResponse(
            response=response_text,
            message_id=f"vscode_{user.id}_{len(request.message)}",
            status="success"
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process chat request: {str(e)}"
        )