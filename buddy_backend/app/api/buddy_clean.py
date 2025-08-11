from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.core.config import settings
from app.core.database import get_db
from app.models.flow import ProjectFlow, FlowCheckpoint, BuddyFlowMessage, FlowStatus, FlowDifficulty, CheckpointType, MessageContext
from app.models.user import User
from app.ai.buddy_ai import BuddyAI
from app.dependencies import get_current_user
import json
import re

router = APIRouter()

class BuddyQuery(BaseModel):
    prompt: str
    chat_history: Optional[List[Dict[str, Any]]] = []

class FlowPreviewRequest(BaseModel):
    prompt: str
    chat_history: Optional[List[Dict[str, Any]]] = []

class FlowConfirmationRequest(BaseModel):
    flow_data: Dict[str, Any]
    confirmed: bool
    modifications: Optional[str] = None

class CheckpointHelpRequest(BaseModel):
    flow_id: int
    checkpoint_id: int
    question: Optional[str] = ""

# Initialize enhanced Buddy AI
buddy_ai = BuddyAI()

@router.post("/buddy/preview-flow")
async def preview_flow(
    request: FlowPreviewRequest,
    current_user: User = Depends(get_current_user)
):
    """Generate a flow preview without saving to database"""
    try:
        # Analyze if this is a flow request
        flow_analysis = await buddy_ai.analyze_flow_request(request.prompt)
        
        if not flow_analysis["is_flow_request"]:
            return {
                "is_flow_request": False,
                "message": "This doesn't appear to be a flow creation request. Try using phrases like 'create flow for...' or 'flow: project description'"
            }
        
        # Generate flow preview using simplified AI approach
        flow_data = await buddy_ai.generate_project_flow(
            description=flow_analysis["project_description"]
        )
        
        # Create preview response
        preview_text = f"""
🎯 **Flow Preview: {flow_data['title']}**

📊 **Project Details:**
- **Difficulty:** {flow_data['difficulty'].title()}
- **Duration:** {flow_data['estimated_duration']}
- **Tags:** {', '.join(flow_data['tags'])}

📋 **Timeline Overview ({len(flow_data['checkpoints'])} checkpoints):**

"""
        
        for i, checkpoint in enumerate(flow_data['checkpoints'], 1):
            checkpoint_icon = "🎯" if checkpoint['type'] == 'milestone' else "✅" if checkpoint['type'] == 'task' else "🔍" if checkpoint['type'] == 'testing' else "📋"
            preview_text += f"""
{checkpoint_icon} **{i}. {checkpoint['title']}** ({checkpoint['estimated_time']})
   {checkpoint['description']}
   
"""

        preview_text += """
💡 **What happens next?**
- Each checkpoint includes detailed guidance and requirements
- I'll be available to help you at every step
- You can track progress and get personalized assistance

**Should I create this flow for you?** Reply with:
- "Yes, create it" or "Add this flow" to proceed
- "Modify: [your changes]" to request adjustments
- "No" to cancel
"""

        return {
            "is_flow_request": True,
            "preview_text": preview_text,
            "flow_data": flow_data,
            "needs_confirmation": True
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating flow preview: {str(e)}")

@router.post("/buddy/confirm-flow")
async def confirm_flow(
    request: FlowConfirmationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Confirm and create the flow, or request modifications"""
    try:
        if not request.confirmed:
            return {"message": "Flow creation cancelled. Let me know if you'd like to create a different flow!"}
        
        flow_data = request.flow_data
        
        # If modifications requested, regenerate flow
        if request.modifications:
            modified_prompt = f"Modify the flow with these changes: {request.modifications}. Original flow was: {flow_data['title']}"
            flow_data = await buddy_ai.generate_project_flow(description=modified_prompt)
        
        # Create flow in database with proper error handling
        try:
            db_flow = ProjectFlow(
                user_id=current_user.id,
                title=flow_data["title"],
                description=flow_data.get("description", "AI-generated project flow"),
                difficulty=FlowDifficulty(flow_data.get("difficulty", "medium")),
                estimated_duration=flow_data.get("estimated_duration", "2-4 weeks"),
                tags=flow_data.get("tags", [])
            )
            
            db.add(db_flow)
            await db.flush()  # Get the flow ID without committing yet
            
            # Create checkpoints with buddy help prompts
            for i, checkpoint_data in enumerate(flow_data["checkpoints"]):
                db_checkpoint = FlowCheckpoint(
                    flow_id=db_flow.id,
                    title=checkpoint_data["title"],
                    description=checkpoint_data["description"],
                    order=i,
                    type=CheckpointType(checkpoint_data.get("type", "task")),
                    estimated_time=checkpoint_data.get("estimated_time", "2-5 days"),
                    requirements=checkpoint_data.get("requirements", []),
                    deliverables=checkpoint_data.get("deliverables", []),
                    buddy_help_prompt=checkpoint_data.get("buddy_help_prompt", f"I'm here to help you with {checkpoint_data['title']}!")
                )
                db.add(db_checkpoint)
            
            await db.commit()
            await db.refresh(db_flow)
            
            response_text = f"""
✅ **Flow Created Successfully!**

🎉 **'{flow_data['title']}'** is now ready with {len(flow_data['checkpoints'])} checkpoints!

📱 **Next Steps:**
1. Go to the Flow tab to see your new project
2. Start with the first checkpoint
3. Ask me for help at any step: "Help with [checkpoint name]"

🤖 **Pro Tip:** I have specialized guidance for each checkpoint. Just mention the checkpoint name and I'll provide targeted assistance!

Ready to start your project? 🚀
"""
            
            return {
                "success": True,
                "message": response_text,
                "flow_id": db_flow.id,
                "flow_title": flow_data["title"]
            }
            
        except Exception as db_error:
            await db.rollback()
            raise HTTPException(status_code=500, detail=f"Database error: {str(db_error)}")
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating flow: {str(e)}")

@router.post("/buddy/checkpoint-help")
async def get_checkpoint_help(
    request: CheckpointHelpRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get AI help for a specific checkpoint"""
    try:
        # Get flow and checkpoint with proper joins
        flow_result = await db.execute(
            select(ProjectFlow)
            .options(joinedload(ProjectFlow.checkpoints))
            .filter(
                ProjectFlow.id == request.flow_id,
                ProjectFlow.user_id == current_user.id
            )
        )
        flow = flow_result.scalar_one_or_none()
        
        if not flow:
            raise HTTPException(status_code=404, detail="Flow not found")
        
        checkpoint_result = await db.execute(
            select(FlowCheckpoint).filter(
                FlowCheckpoint.id == request.checkpoint_id,
                FlowCheckpoint.flow_id == request.flow_id
            )
        )
        checkpoint = checkpoint_result.scalar_one_or_none()
        
        if not checkpoint:
            raise HTTPException(status_code=404, detail="Checkpoint not found")
        
        # Create enhanced prompt for checkpoint help
        enhanced_prompt = f"""
As an expert assistant for the checkpoint "{checkpoint.title}" in the project "{flow.title}", provide detailed guidance.

**Checkpoint Context:**
- Title: {checkpoint.title}
- Description: {checkpoint.description}
- Type: {checkpoint.type.value}
- Estimated Time: {checkpoint.estimated_time}
- Requirements: {', '.join(checkpoint.requirements) if checkpoint.requirements else 'None specified'}
- Deliverables: {', '.join(checkpoint.deliverables) if checkpoint.deliverables else 'None specified'}

**Specific Guidance:** {checkpoint.buddy_help_prompt}

**User's Question:** {request.question if request.question else "General guidance needed"}

Provide actionable, step-by-step guidance to help them succeed with this checkpoint. Be encouraging and practical.
"""
        
        response = await buddy_ai.generate_ai_response(
            prompt=enhanced_prompt,
            chat_history=[]
        )
        
        # Save the help interaction
        help_message = BuddyFlowMessage(
            user_id=current_user.id,
            flow_id=request.flow_id,
            checkpoint_id=request.checkpoint_id,
            content=response,
            role="assistant",
            context=MessageContext.checkpoint_help
        )
        db.add(help_message)
        await db.commit()
        
        return {"response": response}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting checkpoint help: {str(e)}")

@router.post("/buddy/ask")
async def ask_buddy(
    query: BuddyQuery,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Main buddy chat endpoint"""
    try:
        # Check for flow confirmation responses first
        prompt_lower = query.prompt.lower()
        
        # Handle flow confirmation responses
        if any(phrase in prompt_lower for phrase in ['yes, create it', 'add this flow', 'create the flow', 'yes create']):
            return {
                "response": "Great! Please use the flow preview system by asking me to 'create flow for [your project]' to get started with the interactive flow creation process.",
                "suggestion": "Try: 'Create flow for website development' or 'Flow: mobile app project'"
            }
        
        if prompt_lower.startswith('modify:'):
            return {
                "response": "I'd love to help you modify a flow! Please use the flow preview system first by asking me to 'create flow for [your project]', then I can help you customize it.",
                "suggestion": "Try: 'Create flow for [your project]' first"
            }
        
        # Check if this is a flow creation request
        flow_analysis = await buddy_ai.analyze_flow_request(query.prompt)
        
        if flow_analysis["is_flow_request"]:
            # Direct user to preview system for better experience
            return {
                "response": f"""
🎯 I detected you want to create a flow for: **{flow_analysis['project_description']}**

💡 **New Interactive Flow Creation Available!**

I can create a detailed project timeline with checkpoints, but let me show you a preview first so you can review and customize it.

**Use this command for the best experience:**
`/preview-flow {query.prompt}`

Or simply ask: "Preview flow for {flow_analysis['project_description']}"

This way you can:
✅ See the complete timeline before creating
✅ Request modifications if needed  
✅ Get personalized checkpoint guidance

Would you like me to create a preview for your project?
""",
                "flow_detected": True,
                "project_description": flow_analysis['project_description'],
                "suggestion": f"Preview flow for {flow_analysis['project_description']}"
            }
        
        # Regular AI conversation - use simplified response
        response = await buddy_ai.generate_ai_response(
            prompt=query.prompt,
            chat_history=query.chat_history
        )
        
        # Save conversation to database with error handling
        try:
            user_message = BuddyFlowMessage(
                user_id=current_user.id,
                content=query.prompt,
                role="user",
                context=MessageContext.general
            )
            db.add(user_message)
            
            buddy_message = BuddyFlowMessage(
                user_id=current_user.id,
                content=response,
                role="assistant", 
                context=MessageContext.general
            )
            db.add(buddy_message)
            
            await db.commit()
        except Exception as db_error:
            print(f"Database save error: {db_error}")
            # Continue with response even if DB save fails
        
        return {"response": response}
        
    except Exception as e:
        # Enhanced fallback response
        fallback_response = """I apologize, but I'm experiencing technical difficulties. However, I can still help you with:

🎯 **Flow Creation**: Try saying "Create flow for [your project]"
💬 **General Chat**: Ask me questions about project management
📋 **Project Planning**: I can help break down your ideas

What would you like to work on?"""
        
        return {"response": fallback_response}

@router.get("/buddy/status")
async def get_ai_status():
    """Get current AI mode and status"""
    try:
        current_mode = buddy_ai.ai_client.current_mode
        return {
            "current_mode": current_mode,
            "available_modes": ["local", "api"],
            "model_info": {
                "local_model": settings.MODEL_NAME,
                "api_model": settings.GROQ_MODEL
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting status: {str(e)}")
