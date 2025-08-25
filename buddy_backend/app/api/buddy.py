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
from app.services.ai_thinking_service import AIThinkingService
from app.services.github_service import GitHubService
from app.services.system_service import SystemService
import json
import re
from datetime import datetime, timedelta
import uuid
import logging

# Configure logging
logger = logging.getLogger(__name__)

router = APIRouter()

class BuddyQuery(BaseModel):
    prompt: str
    chat_history: Optional[List[Dict[str, Any]]] = []
    is_flow_request: Optional[bool] = False
    persona_id: Optional[str] = None  # Added for persona support
    is_task_continuation: Optional[bool] = False  # For task continuation detection
    recent_context: Optional[str] = None  # Recent conversation context for task continuation
    session_id: Optional[str] = None  # Session identifier for conversation management

class BuddyRequest(BaseModel):
    message: str

class BuddyResponse(BaseModel):
    response: str
    success: bool = True
    thinking_summary: Optional[str] = None
    intent_analysis: Optional[str] = None

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

# Initialize enhanced services
ai_thinking_service = AIThinkingService()
github_service = GitHubService()
system_service = SystemService()

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
@router.post("/buddy/ask", response_model=BuddyResponse)
async def ask_buddy(
    request: BuddyQuery,
    current_user: User = Depends(get_current_user)
) -> BuddyResponse:
    """Enhanced Buddy AI endpoint with intelligent routing and thinking capabilities"""
    try:
        # Handle task continuation requests first
        if request.is_task_continuation and request.recent_context:
            session_info = f"session {request.session_id}" if request.session_id else "no session"
            logger.info(f"Processing task continuation for user {current_user.id if current_user else 'anonymous'} ({session_info})")
            
            # Create enhanced prompt with recent context for task continuation
            enhanced_prompt = f"""Previous context: {request.recent_context}

Current request: {request.prompt}

This is a task continuation request. Please modify or add to the previous task based on the current request."""
            
            # Use buddy AI directly for task continuation with context
            user_id = str(current_user.id) if current_user else None
            buddy_response = await buddy_ai.generate_ai_response(enhanced_prompt, user_id, chat_history=request.chat_history)
            
            # Extract response text from dynamic AI response
            if isinstance(buddy_response, dict):
                if buddy_response.get("type") == "simple_response":
                    response = buddy_response.get("content", "Task updated successfully!")
                elif buddy_response.get("type") == "flow":
                    content = buddy_response.get("content", {})
                    response = f"🔄 Updated Flow: {content.get('title', 'Modified Project Flow')}\n\n"
                    if content.get('description'):
                        response += f"{content.get('description')}\n\n"
                    response += "✅ Flow updated successfully with your requested changes!"
                elif buddy_response.get("type") == "code_solution":
                    content = buddy_response.get("content", {})
                    if content.get("complete_code"):
                        response = f"Here's your updated code:\n\n```{content.get('primary_language', 'python')}\n{content.get('complete_code')}\n```\n\n{content.get('explanation', '')}"
                    else:
                        response = content.get('solution_overview', 'Code updated successfully!')
                elif buddy_response.get("type") == "enhanced_response":
                    content = buddy_response.get("content", {})
                    response = content.get("direct_answer", "Task continuation completed!")
                else:
                    response = str(buddy_response.get("content", buddy_response))
            else:
                response = str(buddy_response)
            
            return BuddyResponse(
                response=response,
                success=True,
                thinking_summary="Task continuation with context awareness",
                intent_analysis="task_continuation"
            )
        
        # Early detection for simple requests that don't need AI thinking overhead
        prompt_lower = request.prompt.lower()
        
        # Simple code generation requests - bypass thinking service for natural responses
        code_keywords = ['generate code', 'write code', 'create code', 'code for', 'build app', 'make program']
        is_simple_code_request = any(keyword in prompt_lower for keyword in code_keywords)
        
        # Simple greetings - bypass thinking service (only for very short greetings)
        greeting_keywords = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening']
        is_simple_greeting = any(request.prompt.strip().lower() == keyword for keyword in greeting_keywords) or (
            any(keyword in prompt_lower for keyword in greeting_keywords) and len(request.prompt.split()) <= 2
        )
        
        if is_simple_code_request or is_simple_greeting:
            # Direct routing without AI thinking overhead for natural ChatGPT-like responses
            logger.info(f"Direct routing (no thinking overhead) for user {current_user.id if current_user else 'anonymous'}")
            
            user_id = str(current_user.id) if current_user else None
            buddy_response = await buddy_ai.generate_ai_response(request.prompt, user_id, chat_history=request.chat_history)
            
            # Format response naturally
            if isinstance(buddy_response, dict):
                if buddy_response.get("type") == "code_solution":
                    content = buddy_response.get("content", {})
                    if content.get("complete_code"):
                        response = f"Here's your calculator code:\n\n```{content.get('primary_language', 'python')}\n{content.get('complete_code')}\n```\n\n{content.get('explanation', '')}"
                    elif content.get("direct_code"):
                        response = content.get("direct_code")
                    else:
                        response = content.get('solution_overview', 'Code generated successfully!')
                elif buddy_response.get("type") == "simple_response":
                    response = buddy_response.get("content", "Hi! How can I help you?")
                elif buddy_response.get("type") == "enhanced_response":
                    content = buddy_response.get("content", {})
                    response = content.get("direct_answer", "I'd be happy to help!")
                else:
                    response = str(buddy_response.get("content", buddy_response))
            else:
                response = str(buddy_response)
            
            return BuddyResponse(
                response=response,
                success=True,
                thinking_summary="Direct natural response",
                intent_analysis="simple_request"
            )
        
        # For complex requests, use AI Thinking Service for intent analysis
        thinking_result = ai_thinking_service.analyze_intent(request.prompt)
        
        response = None
        
        # Route to appropriate service based on intent analysis
        if thinking_result.get("primary_intent") == "github_operations":
            logger.info(f"Routing to GitHub service for user {current_user.id if current_user else 'anonymous'}")
            
            # Extract GitHub operation details from thinking result
            github_intent = thinking_result.get("github_intent", {})
            operation = github_intent.get("operation", "unknown")
            
            if operation == "clone":
                repo_url = github_intent.get("repository_url", "")
                local_path = github_intent.get("local_path", "./cloned_repo")
                result = await github_service.clone_repository(repo_url, local_path)
                response = f"GitHub Clone: {result.get('message', 'Operation completed')}"
                
            elif operation == "status":
                repo_path = github_intent.get("repository_path", ".")
                result = await github_service.get_status(repo_path)
                response = f"Git Status: {result.get('status', 'No changes')}"
                
            elif operation == "commit":
                repo_path = github_intent.get("repository_path", ".")
                message = github_intent.get("commit_message", "Auto commit")
                result = await github_service.commit_changes(repo_path, message)
                response = f"Git Commit: {result.get('message', 'Committed successfully')}"
                
            elif operation == "push":
                repo_path = github_intent.get("repository_path", ".")
                result = await github_service.push_changes(repo_path)
                response = f"Git Push: {result.get('message', 'Pushed successfully')}"
                
            elif operation == "pull":
                repo_path = github_intent.get("repository_path", ".")
                result = await github_service.pull_changes(repo_path)
                response = f"Git Pull: {result.get('message', 'Pulled successfully')}"
                
            else:
                response = "I can help you with GitHub operations like clone, commit, push, pull, and status. What would you like to do?"
                
        elif thinking_result.get("primary_intent") == "system_control":
            logger.info(f"Routing to System service for user {current_user.id if current_user else 'anonymous'}")
            
            # Extract system operation details
            system_intent = thinking_result.get("system_intent", {})
            operation = system_intent.get("operation", "unknown")
            
            if operation == "processes":
                processes = await system_service.get_running_processes()
                process_count = len(processes)
                response = f"System Info: Found {process_count} running processes. Top processes: {', '.join([p['name'] for p in processes[:5]])}"
                
            elif operation == "system_info":
                sys_info = await system_service.get_system_info()
                cpu_percent = sys_info.get('cpu_percent', 'N/A')
                memory_percent = sys_info.get('memory_percent', 'N/A')
                response = f"System Status: CPU: {cpu_percent}%, Memory: {memory_percent}%, Platform: {sys_info.get('platform', 'Unknown')}"
                
            elif operation == "kill_process":
                process_name = system_intent.get("process_name", "")
                if process_name:
                    result = await system_service.kill_process(process_name)
                    response = f"Process Control: {result.get('message', 'Operation completed')}"
                else:
                    response = "Please specify which process you'd like to terminate."
                    
            elif operation == "execute_command":
                command = system_intent.get("command", "")
                if command:
                    result = await system_service.execute_command(command)
                    output = result.get('output', 'No output')[:200]  # Limit output
                    response = f"Command Execution: {output}"
                else:
                    response = "Please specify the command you'd like to execute."
                    
            else:
                response = "I can help you with system operations like viewing processes, system info, killing processes, and executing commands. What would you like to do?"
                
        elif thinking_result.get("primary_intent") in ["flow_generation", "notes", "alarms", "meetings"]:
            # Enhanced flow generation with thinking integration
            logger.info(f"Routing to enhanced Buddy AI for flow generation for user {current_user.id if current_user else 'anonymous'}")
            
            # Generate response strategy
            strategy = ai_thinking_service.generate_response_strategy(thinking_result)
            
            # Use strategy to enhance the buddy AI response
            enhanced_message = f"{request.prompt}\n\nContext: {strategy.get('approach', '')}\nFocus: {', '.join(strategy.get('focus_areas', []))}"
            
            # Use new dynamic AI system with user context
            user_id = str(current_user.id) if current_user else None
            buddy_response = await buddy_ai.generate_ai_response(enhanced_message, user_id, chat_history=request.chat_history)
            
            # Extract response text from dynamic AI response
            if isinstance(buddy_response, dict):
                if buddy_response.get("type") == "simple_response":
                    # For simple greetings, return the natural text directly
                    response = buddy_response.get("content", "Hi! How can I help you?")
                elif buddy_response.get("type") == "flow":
                    # For flow generation, format the response nicely
                    content = buddy_response.get("content", {})
                    response = f"🎯 Generated Flow: {content.get('title', 'Project Flow')}\n\n"
                    if content.get('description'):
                        response += f"{content.get('description')}\n\n"
                    response += "✅ Flow created successfully with personalized timeline, notes, and reminders!"
                elif buddy_response.get("type") == "code_solution":
                    # For code generation, show solution overview
                    content = buddy_response.get("content", {})
                    response = f"💻 Code Solution Generated!\n\n{content.get('solution_overview', 'Complete solution ready')}"
                elif buddy_response.get("type") == "enhanced_response":
                    # For enhanced responses, extract the direct answer (natural ChatGPT-style)
                    content = buddy_response.get("content", {})
                    response = content.get("direct_answer", "I'd be happy to help!")
                else:
                    response = str(buddy_response.get("content", buddy_response))
            else:
                response = str(buddy_response)
            
            # Add thinking insights to response
            thinking_summary = thinking_result.get("summary", "")
            if thinking_summary:
                response = f"{response}\n\n🤔 AI Thinking: {thinking_summary}"
                
        else:
            # General Buddy AI - Natural ChatGPT-like responses without AI strategy overhead
            logger.info(f"Routing to general Buddy AI for user {current_user.id if current_user else 'anonymous'}")
            
            # Check if this is a simple code generation request
            prompt_lower = request.prompt.lower()
            code_keywords = ['generate code', 'write code', 'create code', 'code for', 'build app', 'make program']
            is_simple_code_request = any(keyword in prompt_lower for keyword in code_keywords)
            
            # Use natural AI system directly without strategy overhead for code requests
            user_id = str(current_user.id) if current_user else None
            
            if is_simple_code_request:
                # Direct code generation without AI strategy interference 
                buddy_response = await buddy_ai.generate_ai_response(request.prompt, user_id, chat_history=request.chat_history)
            else:
                # For non-code requests, we can add some light strategy context
                strategy = ai_thinking_service.generate_response_strategy(thinking_result)
                enhanced_message = f"{request.prompt}\n\nContext: {strategy.get('approach', '')}"
                buddy_response = await buddy_ai.generate_ai_response(enhanced_message, user_id, chat_history=request.chat_history)
            
            # Extract response text from dynamic AI response
            if isinstance(buddy_response, dict):
                if buddy_response.get("type") == "simple_response":
                    # For simple responses, return the natural text directly
                    response = buddy_response.get("content", "Hi! How can I help you?")
                elif buddy_response.get("type") == "code_solution":
                    # For code generation, format the response properly
                    content = buddy_response.get("content", {})
                    if content.get("complete_code"):
                        response = f"Here's your calculator code:\n\n```{content.get('primary_language', 'python')}\n{content.get('complete_code')}\n```\n\n{content.get('explanation', '')}"
                    elif content.get("direct_code"):
                        response = content.get("direct_code")
                    else:
                        response = content.get('solution_overview', 'Code generated successfully!')
                elif buddy_response.get("type") == "enhanced_response":
                    content = buddy_response.get("content", {})
                    response = content.get("direct_answer", "I'd be happy to help!")
                elif buddy_response.get("type") == "error":
                    content = buddy_response.get("content", {})
                    response = f"I encountered an issue: {content.get('error', 'Unknown error')}"
                else:
                    response = str(buddy_response.get("content", buddy_response))
            else:
                response = str(buddy_response)
        
        # Log the interaction for debugging
        logger.info(f"Buddy AI Response - Intent: {thinking_result.get('primary_intent', 'general')}, User: {current_user.id if current_user else 'anonymous'}")
        
        return BuddyResponse(
            response=response or "I'm here to help! You can ask me about flows, GitHub operations, system control, or general assistance.",
            success=True,
            thinking_summary=thinking_result.get("summary", ""),
            intent_analysis=thinking_result.get("primary_intent", "general")
        )
        
    except Exception as e:
        logger.error(f"Error in ask_buddy: {str(e)}")
        return BuddyResponse(
            response=f"I encountered an error: {str(e)}. Please try again or rephrase your request.",
            success=False,
            thinking_summary="Error occurred during processing",
            intent_analysis="error"
        )

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

@router.post("/buddy/generate-flow-notes")
async def generate_flow_notes(
    request: dict,
    current_user: User = Depends(get_current_user)
):
    """Generate notes for a specific flow when requested"""
    try:
        flow_id = request.get("flow_id")
        flow_data = request.get("flow_data", {})
        
        user_id = str(current_user.id) if current_user else None
        user_context = await buddy_ai.get_user_context(user_id) if user_id else {}
        relevant_knowledge = await buddy_ai.get_relevant_context(f"notes for {flow_data.get('title', '')}", limit=3)
        
        notes = await buddy_ai.generate_flow_notes(flow_data, user_context, relevant_knowledge)
        
        return {
            "success": True,
            "notes": notes,
            "message": "Notes generated successfully!"
        }
        
    except Exception as e:
        logger.error(f"Error generating flow notes: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to generate notes"
        }

@router.post("/buddy/generate-flow-alarms")
async def generate_flow_alarms(
    request: dict,
    current_user: User = Depends(get_current_user)
):
    """Generate alarms for a specific flow when requested"""
    try:
        flow_id = request.get("flow_id")
        flow_data = request.get("flow_data", {})
        
        user_id = str(current_user.id) if current_user else None
        user_context = await buddy_ai.get_user_context(user_id) if user_id else {}
        
        alarms = await buddy_ai.generate_flow_alarms(flow_data, user_context)
        
        return {
            "success": True,
            "alarms": alarms,
            "message": "Alarms generated successfully!"
        }
        
    except Exception as e:
        logger.error(f"Error generating flow alarms: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to generate alarms"
        }
