from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.core.config import settings
from app.core.database import get_db
from app.models.flow import ProjectFlow, FlowCheckpoint, BuddyFlowMessage, FlowStatus, FlowDifficulty, CheckpointType, MessageContext
from app.models.user import User
from app.ai.model_loader import load_ai_model
from app.ai.buddy_ai import BuddyAI
from app.dependencies import get_current_user
import json
import re

router = APIRouter()

class BuddyQuery(BaseModel):
    prompt: str
    chat_history: Optional[List[Dict[str, str]]] = []
    is_flow_request: Optional[bool] = False

class TimelineQuery(BaseModel):
    project_description: str
    chat_history: Optional[List[Dict[str, str]]] = []

class CheckpointHelp(BaseModel):
    task_id: str
    checkpoint: str
    chat_history: Optional[List[Dict[str, str]]] = []

class FlowGenerationRequest(BaseModel):
    project_description: str
    chat_history: Optional[List[Dict[str, str]]] = []

class FlowProgressUpdate(BaseModel):
    flow_id: int
    checkpoint_index: int
    is_completed: bool

MODEL_NAME = settings.MODEL_NAME
MODEL_PATH = settings.MODEL_PATH

try:
    ai_model = load_ai_model(MODEL_NAME, MODEL_PATH)
except Exception as e:
    print(f"❌ Failed to load model: {e}")
    ai_model = None

# Initialize enhanced Buddy AI
buddy_ai = BuddyAI()

@router.post("/ask")
async def ask_buddy(
    query: BuddyQuery,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        # Check if this is a flow creation request
        flow_analysis = await buddy_ai.analyze_flow_request(query.prompt)
        
        if flow_analysis["is_flow_request"]:
            # Generate project flow
            flow_data = await buddy_ai.generate_project_flow(
                description=flow_analysis["project_description"]
            )
            
            # Create flow in database
            db_flow = ProjectFlow(
                user_id=current_user.id,
                title=flow_data["title"],
                description=flow_analysis["project_description"],
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
            await db.refresh(db_flow)
            
            response_text = f"I've created a project flow for '{flow_data['title']}' with {len(flow_data['checkpoints'])} checkpoints! You can track your progress and get help at each step. The estimated duration is {flow_data['estimated_duration']}."
            
            # Save the conversation
            user_message = BuddyFlowMessage(
                user_id=current_user.id,
                flow_id=db_flow.id,
                content=query.prompt,
                role="user",
                context=MessageContext.flow_creation
            )
            db.add(user_message)
            
            ai_message = BuddyFlowMessage(
                user_id=current_user.id,
                flow_id=db_flow.id,
                content=response_text,
                role="assistant",
                context=MessageContext.flow_creation
            )
            db.add(ai_message)
            await db.commit()
            
            return {
                "response": response_text,
                "flow_data": {
                    "id": db_flow.id,
                    "title": flow_data["title"],
                    "checkpoints": flow_data["checkpoints"],
                    "estimated_duration": flow_data["estimated_duration"],
                    "difficulty": flow_data["difficulty"]
                },
                "is_flow_created": True
            }
        
        else:
            # Regular chat response
            if ai_model is None:
                response_text = "I'm currently not available. The AI model is not loaded. Please try again later."
            else:
                # Build context with chat history
                context = "You are Buddy, a helpful AI assistant. Previous conversation:\n"
                for msg in query.chat_history[-10:]:  # Last 10 messages for context
                    role = "User" if msg.get('role') == 'user' else "Buddy"
                    context += f"{role}: {msg.get('content', '')}\n"
                
                context += f"\nUser: {query.prompt}\nBuddy:"
                response_text = ai_model.generate_response(context)
            
            # Save general conversation
            user_message = BuddyFlowMessage(
                user_id=current_user.id,
                content=query.prompt,
                role="user",
                context=MessageContext.general
            )
            db.add(user_message)
            
            ai_message = BuddyFlowMessage(
                user_id=current_user.id,
                content=response_text,
                role="assistant",
                context=MessageContext.general
            )
            db.add(ai_message)
            await db.commit()
            
            return {
                "response": response_text,
                "is_flow_created": False
            }
            
    except Exception as e:
        return {"response": f"I encountered an error: {str(e)}. Please try again."}

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
        await db.refresh(db_flow)
        
        return {"flow": db_flow}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating flow: {str(e)}")

@router.post("/buddy/checkpoint-help")
async def get_checkpoint_help(
    flow_id: int,
    checkpoint_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get AI help for a specific checkpoint"""
    try:
        # Get flow and checkpoint
        flow_result = await db.execute(select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        ))
        flow = flow_result.scalar_one_or_none()
        
        if not flow:
            raise HTTPException(status_code=404, detail="Flow not found")
        
        checkpoint_result = await db.execute(select(FlowCheckpoint).filter(
            FlowCheckpoint.id == checkpoint_id,
            FlowCheckpoint.flow_id == flow_id
        ))
        checkpoint = checkpoint_result.scalar_one_or_none()
        
        if not checkpoint:
            raise HTTPException(status_code=404, detail="Checkpoint not found")
        
        # Get recent chat history for context
        messages_result = await db.execute(select(BuddyFlowMessage).filter(
            BuddyFlowMessage.user_id == current_user.id,
            BuddyFlowMessage.flow_id == flow_id
        ).order_by(BuddyFlowMessage.timestamp.desc()).limit(10))
        recent_messages = messages_result.scalars().all()
        
        # Generate help using AI
        help_content = await buddy_ai.get_checkpoint_help(
            flow=flow,
            checkpoint=checkpoint,
            chat_history=[msg.content for msg in reversed(recent_messages)]
        )
        
        # Save the help message
        help_message = BuddyFlowMessage(
            user_id=current_user.id,
            flow_id=flow_id,
            checkpoint_id=checkpoint_id,
            content=help_content,
            role="assistant",
            context=MessageContext.checkpoint_help
        )
        db.add(help_message)
        await db.commit()
        
        return {"help": help_content}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting help: {str(e)}")

@router.post("/buddy/flow-progress")
async def update_flow_progress(
    request: FlowProgressUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update flow progress and get AI encouragement"""
    try:
        flow_result = await db.execute(select(ProjectFlow).filter(
            ProjectFlow.id == request.flow_id,
            ProjectFlow.user_id == current_user.id
        ))
        flow = flow_result.scalar_one_or_none()
        
        if not flow:
            raise HTTPException(status_code=404, detail="Flow not found")
        
        # Generate progress message using AI
        progress_message = await buddy_ai.generate_progress_message(
            flow=flow,
            checkpoint_index=request.checkpoint_index,
            is_completed=request.is_completed
        )
        
        # Save progress message
        progress_msg = BuddyFlowMessage(
            user_id=current_user.id,
            flow_id=request.flow_id,
            content=progress_message,
            role="assistant",
            context=MessageContext.flow_progress
        )
        db.add(progress_msg)
        await db.commit()
        
        return {"message": progress_message}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating progress: {str(e)}")

@router.post("/buddy/generate-timeline")
async def generate_project_timeline(query: TimelineQuery):
    if ai_model is None:
        # Fallback response
        return _fallback_timeline_response(query.project_description)

    try:
        prompt = f"""Create a detailed project timeline for: {query.project_description}

Please provide:
1. Estimated duration (in days/weeks)
2. Difficulty level (Easy/Medium/Hard)
3. List of tasks with title, description, and duration
4. Milestones and checkpoints

Format your response as a structured timeline that can be broken into manageable tasks."""

        response = ai_model.generate_response(prompt)
        
        # Parse AI response into structured data
        timeline_data = _parse_timeline_response(response, query.project_description)
        return timeline_data
        
    except Exception as e:
        return _fallback_timeline_response(query.project_description)

@router.post("/buddy/checkpoint-help")
async def get_checkpoint_help(query: CheckpointHelp):
    if ai_model is None:
        return {"help": "I'm currently not available to provide checkpoint help. Please try again later."}

    try:
        prompt = f"""The user is working on task {query.task_id} and has reached checkpoint: {query.checkpoint}

Please provide specific, actionable help for this checkpoint. Include:
1. What they should focus on at this stage
2. Common challenges and how to overcome them
3. Resources or tools that might help
4. Next steps after completing this checkpoint

Be encouraging and practical in your advice."""

        response = ai_model.generate_response(prompt)
        return {"help": response}
        
    except Exception as e:
        return {"help": f"Sorry, I couldn't provide help for this checkpoint: {str(e)}"}

def _fallback_timeline_response(project_description: str):
    """Fallback response when AI model is not available"""
    return {
        "timeline": [
            {"phase": "Planning", "duration": "2 days", "description": "Research and plan the project"},
            {"phase": "Development", "duration": "5 days", "description": "Main development work"},
            {"phase": "Testing", "duration": "2 days", "description": "Test and debug"},
            {"phase": "Deployment", "duration": "1 day", "description": "Deploy and finalize"}
        ],
        "estimated_duration": "1-2 weeks",
        "difficulty": "Medium",
        "tasks": [
            {
                "title": "Project Research",
                "description": f"Research requirements for: {project_description}",
                "duration": "1 day",
                "checkpoint": "research_complete"
            },
            {
                "title": "Setup Development Environment",
                "description": "Set up tools and environment needed for development",
                "duration": "0.5 days",
                "checkpoint": "environment_ready"
            },
            {
                "title": "Core Development",
                "description": "Implement main features and functionality",
                "duration": "4 days",
                "checkpoint": "core_complete"
            },
            {
                "title": "Testing & Bug Fixes",
                "description": "Test thoroughly and fix any issues found",
                "duration": "2 days",
                "checkpoint": "testing_complete"
            },
            {
                "title": "Final Polish",
                "description": "Final touches and optimization",
                "duration": "1 day",
                "checkpoint": "project_complete"
            }
        ]
    }

def _parse_timeline_response(ai_response: str, project_description: str):
    """Parse AI response into structured timeline data"""
    try:
        # Try to extract structured information from AI response
        lines = ai_response.split('\n')
        
        # Extract duration
        duration_match = re.search(r'(\d+)\s*(day|week|month)', ai_response.lower())
        estimated_duration = f"{duration_match.group(1)} {duration_match.group(2)}s" if duration_match else "1-2 weeks"
        
        # Extract difficulty
        difficulty = "Medium"
        if any(word in ai_response.lower() for word in ['easy', 'simple', 'basic']):
            difficulty = "Easy"
        elif any(word in ai_response.lower() for word in ['hard', 'complex', 'difficult', 'advanced']):
            difficulty = "Hard"
        
        # For now, return fallback with AI response included
        fallback = _fallback_timeline_response(project_description)
        fallback['ai_response'] = ai_response
        fallback['estimated_duration'] = estimated_duration
        fallback['difficulty'] = difficulty
        
        return fallback
        
    except Exception:
        return _fallback_timeline_response(project_description)
