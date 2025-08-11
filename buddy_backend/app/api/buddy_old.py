from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
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
    is_flow_request: Optional[bool] = False

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
        
        # Regular AI conversation - use Groq API directly
        response = await buddy_ai.generate_ai_response(
            prompt=query.prompt,
            chat_history=query.chat_history
        )
        
        # Save conversation to database
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
        
        return {"response": response}
        
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
        
        return {"response": fallback_response}

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
        flow_result = await db.execute(
            select(ProjectFlow).filter(
                ProjectFlow.id == flow_id,
                ProjectFlow.user_id == current_user.id
            )
        )
        flow = flow_result.scalar_one_or_none()
        
        if not flow:
            raise HTTPException(status_code=404, detail="Flow not found")
        
        checkpoint_result = await db.execute(
            select(FlowCheckpoint).filter(
                FlowCheckpoint.id == checkpoint_id,
                FlowCheckpoint.flow_id == flow_id
            )
        )
        checkpoint = checkpoint_result.scalar_one_or_none()
        
        if not checkpoint:
            raise HTTPException(status_code=404, detail="Checkpoint not found")
        
        # Get recent chat history for context
        messages_result = await db.execute(
            select(BuddyFlowMessage).filter(
                BuddyFlowMessage.user_id == current_user.id,
                BuddyFlowMessage.flow_id == flow_id
            ).order_by(BuddyFlowMessage.timestamp.desc()).limit(10)
        )
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
        flow_result = await db.execute(
            select(ProjectFlow).filter(
                ProjectFlow.id == request.flow_id,
                ProjectFlow.user_id == current_user.id
            )
        )
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
    try:
        prompt = f"""Create a detailed project timeline for: {query.project_description}

Please provide:
1. Estimated duration (in days/weeks)
2. Difficulty level (Easy/Medium/Hard)
3. List of tasks with title, description, and duration
4. Milestones and checkpoints

Format your response as a structured timeline that can be broken into manageable tasks."""

        response = await buddy_ai.generate_ai_response(prompt)
        
        # Parse AI response into structured data
        timeline_data = _parse_timeline_response(response, query.project_description)
        return timeline_data
        
    except Exception as e:
        return _fallback_timeline_response(query.project_description)

@router.post("/buddy/checkpoint-help")
async def get_checkpoint_help(query: CheckpointHelp):
    try:
        prompt = f"""The user is working on task {query.task_id} and has reached checkpoint: {query.checkpoint}

Please provide specific, actionable help for this checkpoint. Include:
1. What they should focus on at this stage
2. Common challenges and how to overcome them
3. Resources or tools that might help
4. Next steps after completing this checkpoint

Be encouraging and practical in your advice."""

        response = await buddy_ai.generate_ai_response(prompt)
        return {"help": response}
        
    except Exception as e:
        return {"help": f"Sorry, I couldn't provide help for this checkpoint: {str(e)}"}

def _generate_simple_response(prompt: str) -> str:
    """Generate simple conversational responses when AI is unavailable"""
    prompt_lower = prompt.lower().strip()
    
    # Greetings
    if any(word in prompt_lower for word in ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening']):
        return "Hello! I'm your Buddy assistant. I can help you with project management, creating flows, and general questions. How can I assist you today?"
    
    # How are you
    if any(phrase in prompt_lower for phrase in ['how are you', 'how do you do', 'how\'s it going']):
        return "I'm doing well, thank you for asking! I'm here and ready to help you with your projects. What would you like to work on?"
    
    # What can you do
    if any(phrase in prompt_lower for phrase in ['what can you do', 'what do you do', 'help me', 'what are you', 'who are you']):
        return """I'm Buddy, your AI assistant! I can help you with:

🎯 **Project Flows**: Create structured project timelines with checkpoints
📋 **Task Management**: Break down complex projects into manageable steps  
💬 **General Chat**: Answer questions and provide guidance
🔧 **Project Help**: Assist with specific project challenges

Try saying:
- "Create flow for website development"
- "Help me plan a mobile app"
- Or just ask me anything!

What would you like to work on?"""
    
    # Thank you
    if any(word in prompt_lower for word in ['thank', 'thanks', 'thx']):
        return "You're welcome! I'm always here to help. Is there anything else you'd like to work on?"
    
    # Goodbye
    if any(word in prompt_lower for word in ['bye', 'goodbye', 'see you', 'later']):
        return "Goodbye! Feel free to come back anytime you need help with your projects. Have a great day!"
    
    # Questions about buddy
    if any(word in prompt_lower for word in ['buddy', 'your name']):
        return "I'm Buddy, your AI project assistant! I specialize in helping you create and manage projects through structured flows and providing guidance along the way."
    
    # Weather (common question)
    if 'weather' in prompt_lower:
        return "I don't have access to weather information, but I can help you plan projects that might be weather-dependent! What are you working on?"
    
    # Time questions
    if any(word in prompt_lower for word in ['time', 'date', 'today']):
        return "I can help you manage project timelines and deadlines! Are you working on any projects that need scheduling?"
    
    # Programming questions
    if any(word in prompt_lower for word in ['code', 'coding', 'programming', 'development', 'developer']):
        return "I can help you plan software development projects! Try asking me to 'create flow for [your project]' to get a structured development timeline."
    
    # General work/project questions
    if any(word in prompt_lower for word in ['work', 'project', 'task', 'job']):
        return "I'd love to help you with your work or project! Can you tell me more about what you're working on? I can create structured flows to help you organize and complete your tasks."
    
    # Default conversational response
    return f"""That's an interesting question! While I'm currently in basic mode, I can still help you with project planning and management.

Here are some things I can do:
🎯 **Create Project Flows**: Ask me to "create flow for [your project]"
📋 **Project Planning**: Help break down ideas into actionable steps
💡 **General Guidance**: Provide advice on project management

What would you like to work on today?"""

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
            "model_info": {
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
