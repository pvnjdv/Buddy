from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.core.config import settings
from app.core.database import get_db
from app.models.flow import ProjectFlow, FlowCheckpoint, BuddyFlowMessage, FlowStatus, FlowDifficulty, CheckpointType, MessageContext, FlowAlarm as FlowAlarmModel, AlarmType, AlarmRepeat
from app.models.user import User
from app.models.persona import AIPersona  # Added for persona support
from app.ai.buddy_ai import BuddyAI
from app.dependencies import get_current_user
from app.crud.persona import persona_crud  # Added for persona operations
import json
import re
from datetime import datetime, timedelta
import uuid

router = APIRouter()

class BuddyQuery(BaseModel):
    prompt: str
    chat_history: Optional[List[Dict[str, Any]]] = []
    is_flow_request: Optional[bool] = False
    persona_id: Optional[str] = None  # Added for persona support

class TimelineQuery(BaseModel):
    project_description: str
    chat_history: Optional[List[Dict[str, Any]]] = []

class CheckpointHelp(BaseModel):
    task_id: str
    checkpoint: str
    chat_history: Optional[List[Dict[str, Any]]] = []

class FlowGenerationRequest(BaseModel):
    project_description: str
    chat_history: Optional[List[Dict[str, str]]] = []

class FlowProgressUpdate(BaseModel):
    flow_id: int
    checkpoint_index: int
    is_completed: bool

# Initialize enhanced Buddy AI with unified AI client
buddy_ai = BuddyAI()

class FlowPreviewRequest(BaseModel):
    prompt: str
    chat_history: Optional[List[Dict[str, Any]]] = []

class FlowConfirmationRequest(BaseModel):
    flow_data: Dict[str, Any]
    confirmed: bool
    modifications: Optional[str] = None

# Add new endpoint for flow preview
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
        
        # Generate flow preview
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
        
        # Create flow in database
        db_flow = ProjectFlow(
            user_id=current_user.id,
            title=flow_data["title"],
            description=flow_data.get("description", "AI-generated project flow"),
            difficulty=FlowDifficulty(flow_data.get("difficulty", "medium")),
            estimated_duration=flow_data.get("estimated_duration", "1 week"),
            tags=flow_data.get("tags", [])
        )
        
        db.add(db_flow)
        await db.commit()
        await db.refresh(db_flow)
        
        # Create checkpoints with buddy help prompts
        for i, checkpoint_data in enumerate(flow_data["checkpoints"]):
            db_checkpoint = FlowCheckpoint(
                flow_id=db_flow.id,
                title=checkpoint_data["title"],
                description=checkpoint_data["description"],
                order=i,
                type=CheckpointType(checkpoint_data.get("type", "task")),
                estimated_time=checkpoint_data.get("estimated_time", "1 day"),
                requirements=checkpoint_data.get("requirements", []),
                deliverables=checkpoint_data.get("deliverables", []),
                buddy_help_prompt=checkpoint_data.get("buddy_help_prompt", f"I'm here to help you with {checkpoint_data['title']}!")
            )
            db.add(db_checkpoint)
        
        await db.commit()
        
        # Auto-create sequential alarms for each checkpoint (best-effort)
        try:
            result = await db.execute(
                select(FlowCheckpoint).filter(FlowCheckpoint.flow_id == db_flow.id)
            )
            checkpoints = result.scalars().all()
            await _create_default_alarms_for_flow(db, current_user.id, db_flow, checkpoints)
        except Exception:
            pass
        
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
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating flow: {str(e)}")

@router.post("/buddy/generate-flow")
async def generate_flow(
    request: FlowGenerationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Generate a project flow from description"""
    try:
        flow_data = await buddy_ai.generate_project_flow(
            description=request.project_description
        )
        
        # Create flow in database
        db_flow = ProjectFlow(
            user_id=current_user.id,
            title=flow_data["title"],
            description=request.project_description,
            difficulty=FlowDifficulty(flow_data.get("difficulty", "medium")),
            estimated_duration=flow_data.get("estimated_duration", "1 week"),
            tags=flow_data.get("tags", [])
        )
        
        db.add(db_flow)
        await db.commit()
        await db.refresh(db_flow)
        
        # Create checkpoints
        for i, checkpoint_data in enumerate(flow_data["checkpoints"]):
            db_checkpoint = FlowCheckpoint(
                flow_id=db_flow.id,
                title=checkpoint_data["title"],
                description=checkpoint_data["description"],
                order=i,
                type=CheckpointType(checkpoint_data.get("type", "task")),
                estimated_time=checkpoint_data.get("estimated_time", "1 day"),
                requirements=checkpoint_data.get("requirements", []),
                deliverables=checkpoint_data.get("deliverables", [])
            )
            db.add(db_checkpoint)
        
        await db.commit()

        # Auto-create sequential alarms for each checkpoint (best-effort)
        try:
            result = await db.execute(
                select(FlowCheckpoint).filter(FlowCheckpoint.flow_id == db_flow.id)
            )
            checkpoints = result.scalars().all()
            await _create_default_alarms_for_flow(db, current_user.id, db_flow, checkpoints)
        except Exception:
            pass
        
        # Refresh with eager loading to avoid MissingGreenlet error
        result = await db.execute(
            select(ProjectFlow)
            .options(
                selectinload(ProjectFlow.checkpoints).selectinload(FlowCheckpoint.resources)
            )
            .filter(ProjectFlow.id == db_flow.id)
        )
        db_flow = result.scalar_one()
        
        return {"flow": db_flow}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating flow: {str(e)}")

# Enhanced checkpoint help endpoint
@router.post("/buddy/checkpoint-help")
async def get_checkpoint_help(
    checkpoint_help: CheckpointHelp,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get specific help for a checkpoint"""
    try:
        # Get the specific checkpoint from database
        result = await db.execute(
            select(FlowCheckpoint).filter(
                FlowCheckpoint.flow_id == checkpoint_help.task_id,
                FlowCheckpoint.title.ilike(f"%{checkpoint_help.checkpoint}%")
            )
        )
        checkpoint = result.scalar_one_or_none()
        
        if checkpoint and checkpoint.buddy_help_prompt:
            # Use the specific help prompt for this checkpoint
            enhanced_prompt = f"""
As an expert assistant for the checkpoint "{checkpoint.title}", provide detailed guidance.

Context: {checkpoint.description}
Requirements: {', '.join(checkpoint.requirements) if checkpoint.requirements else 'None specified'}
Deliverables: {', '.join(checkpoint.deliverables) if checkpoint.deliverables else 'None specified'}

Specific guidance: {checkpoint.buddy_help_prompt}

User's question or current situation: {checkpoint_help.checkpoint if not checkpoint_help.checkpoint in checkpoint.title else "General guidance needed"}

Provide actionable, step-by-step guidance to help them succeed with this checkpoint.
"""
        else:
            # Fallback to general checkpoint help
            enhanced_prompt = f"""
Help the user with their project checkpoint: {checkpoint_help.checkpoint}

Provide specific, actionable guidance including:
1. Step-by-step instructions
2. Best practices and tips
3. Common pitfalls to avoid
4. Resources or tools that might help
5. How to measure success

Make your response practical and encouraging.
"""
        
        response = await buddy_ai.generate_ai_response(
            prompt=enhanced_prompt,
            chat_history=checkpoint_help.chat_history
        )
        
        return {"response": response}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting checkpoint help: {str(e)}")

# Original ask endpoint - enhanced for flow integration
@router.post("/buddy/ask")
async def ask_buddy(
    query: BuddyQuery,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        # Get the persona if persona_id is provided
        active_persona = None
        if query.persona_id:
            active_persona = await persona_crud.get_persona_by_id(db, query.persona_id, str(current_user.id))
            if not active_persona:
                return {
                    "error": "Persona not found",
                    "response": "The requested AI persona was not found. Using default Buddy instead."
                }
        else:
            # If no persona_id specified, check for user's active persona
            active_persona = await persona_crud.get_active_persona(db, str(current_user.id))

        # Check for flow confirmation responses first
        prompt_lower = query.prompt.lower()
        
        # Handle flow confirmation responses
        if any(phrase in prompt_lower for phrase in ['yes, create it', 'add this flow', 'create the flow', 'yes create']):
            response_text = "Great! Please use the flow preview system by asking me to 'create flow for [your project]' to get started with the interactive flow creation process."
            if active_persona:
                persona_response = await buddy_ai.generate_persona_response(
                    prompt=response_text,
                    persona=active_persona,
                    chat_history=query.chat_history
                )
                response_text = persona_response
            
            return {
                "response": response_text,
                "suggestion": "Try: 'Create flow for website development' or 'Flow: mobile app project'",
                "active_persona": {
                    "id": active_persona.id,
                    "name": active_persona.name
                } if active_persona else None
            }
        
        if prompt_lower.startswith('modify:'):
            response_text = "I'd love to help you modify a flow! Please use the flow preview system first by asking me to 'create flow for [your project]', then I can help you customize it."
            if active_persona:
                persona_response = await buddy_ai.generate_persona_response(
                    prompt=response_text,
                    persona=active_persona,
                    chat_history=query.chat_history
                )
                response_text = persona_response
            
            return {
                "response": response_text,
                "suggestion": "Try: 'Create flow for [your project]' first",
                "active_persona": {
                    "id": active_persona.id,
                    "name": active_persona.name
                } if active_persona else None
            }
        
        # Check if this is a flow creation request
        flow_analysis = await buddy_ai.analyze_flow_request(query.prompt)
        
        if flow_analysis["is_flow_request"]:
            # Direct user to preview system for better experience
            base_response = f"""
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
"""
            
            # Apply persona if available
            if active_persona:
                persona_response = await buddy_ai.generate_persona_response(
                    prompt=f"The user wants to create a project flow for: {flow_analysis['project_description']}. Guide them to use the flow preview system.",
                    persona=active_persona,
                    chat_history=query.chat_history
                )
                response_text = persona_response
            else:
                response_text = base_response
            
            return {
                "response": response_text,
                "flow_detected": True,
                "project_description": flow_analysis['project_description'],
                "suggestion": f"Preview flow for {flow_analysis['project_description']}",
                "active_persona": {
                    "id": active_persona.id,
                    "name": active_persona.name
                } if active_persona else None
            }
        
        # Regular AI conversation - use persona if available
        if active_persona:
            response = await buddy_ai.generate_persona_response(
                prompt=query.prompt,
                persona=active_persona,
                chat_history=query.chat_history
            )
        else:
            response = await buddy_ai.generate_ai_response(
                prompt=query.prompt,
                chat_history=query.chat_history
            )
        
        # Save conversation to database with persona context
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
        
        return {
            "response": response,
            "active_persona": {
                "id": active_persona.id,
                "name": active_persona.name,
                "description": active_persona.description
            } if active_persona else None
        }
        
    except Exception as e:
        # Fallback response
        fallback_response = "I apologize, but I'm experiencing technical difficulties. Please try again in a moment. If you're trying to create a flow, try using 'create flow for [your project]' format."
        
        try:
            # Save error interaction
            error_message = BuddyFlowMessage(
                user_id=current_user.id,
                content=query.prompt,
                role="user",
                context=MessageContext.general
            )
            db.add(error_message)
            
            fallback_message = BuddyFlowMessage(
                user_id=current_user.id,
                content=fallback_response,
                role="assistant",
                context=MessageContext.general
            )
            db.add(fallback_message)
            
            await db.commit()
        except:
            pass  # If database operations fail, just return the response
        
        return {
            "response": fallback_response,
            "error": str(e)
        }

# Helper: Create default alarms sequentially for a flow
async def _create_default_alarms_for_flow(
    db: AsyncSession,
    user_id: int,
    flow: ProjectFlow,
    checkpoints: List[FlowCheckpoint]
):
    cursor = datetime.utcnow()
    for cp in sorted(checkpoints, key=lambda c: c.order):
        duration = _parse_estimated_duration(cp.estimated_time or "1 day")
        scheduled = cursor + duration
        alarm = FlowAlarmModel(
            id=str(uuid.uuid4()),
            user_id=user_id,
            title=f"{flow.title}: {cp.title}",
            description=f"Deadline for checkpoint '{cp.title}'",
            scheduled_time=scheduled,
            type=AlarmType.deadline if cp.type in {CheckpointType.milestone, CheckpointType.review, CheckpointType.testing} else AlarmType.task,
            repeat=AlarmRepeat.none,
            flow_id=flow.id,
            checkpoint_id=cp.id,
            is_active=True,
            created_at=datetime.utcnow(),
        )
        db.add(alarm)
        cursor = scheduled
    await db.commit()

# Parse durations like "2-3 days", "5 days", "1 week", "3-4 weeks", "8 hours"
def _parse_estimated_duration(text: str) -> timedelta:
    try:
        s = (text or "").strip().lower()
        m = re.search(r"(?:(\d+)\s*-\s*)?(\d+)\s*(day|days|week|weeks|hour|hours)", s)
        if m:
            start = int(m.group(1)) if m.group(1) else None
            end = int(m.group(2))
            unit = m.group(3)
            value = end if start is not None else end
            if unit in ("day", "days"):
                return timedelta(days=value)
            if unit in ("week", "weeks"):
                return timedelta(days=value * 7)
            if unit in ("hour", "hours"):
                return timedelta(hours=value)
        if "week" in s:
            return timedelta(days=7)
        if "day" in s:
            return timedelta(days=1)
        if "hour" in s:
            return timedelta(hours=8)
    except Exception:
        pass
    return timedelta(days=1)

class ModeSwitch(BaseModel):
    mode: str  # "local" or "api"

@router.get("/buddy/status")
async def get_ai_status():
    """Get current AI mode and status"""
    try:
        current_mode = buddy_ai.ai_client.current_mode
        return {
            "current_mode": current_mode,
            "available_modes": ["local", "api"],
            "models": {
                "local_model": settings.MODEL_NAME,
                "api_model": settings.GROQ_MODEL
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting status: {str(e)}")

@router.post("/buddy/switch-mode")
async def switch_ai_mode(mode_request: ModeSwitch):
    """Switch between local and API AI modes"""
    try:
        if mode_request.mode not in ["local", "api"]:
            raise HTTPException(status_code=400, detail="Mode must be 'local' or 'api'")
        
        buddy_ai.ai_client.switch_mode(mode_request.mode)
        
        return {
            "message": f"AI mode switched to {mode_request.mode}",
            "current_mode": mode_request.mode
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error switching mode: {str(e)}")
