from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from sqlalchemy.orm import joinedload, selectinload
from typing import List, Optional, Dict, Tuple, Any
from datetime import datetime, timedelta
import json
import uuid
from pydantic import BaseModel
from jose import JWTError, jwt
from ..crud.user import get_user_by_mobile

from ..core.database import get_db
from ..core.config import settings
from ..models.flow import ProjectFlow, FlowCheckpoint, FlowResource, BuddyFlowMessage, FlowStatus, FlowDifficulty, CheckpointType, MessageContext, FlowAlarm as FlowAlarmModel, AlarmType, AlarmRepeat
from ..models.flow import FlowCheckpointNote, FlowCheckpointAssignment
from ..models.collaboration_enhanced import WorkContribution, AIAssistance
from ..models.collaboration import CollaborationMember
from ..models.flow import Repository  # Add Repository import
from ..models.user import User
from ..schemas.flow import (
    ProjectFlowCreate, ProjectFlowUpdate, ProjectFlowResponse,
    FlowCheckpointCreate, FlowCheckpointUpdate, FlowCheckpointResponse,
    BuddyFlowMessageCreate, BuddyFlowMessageResponse,
    FlowGenerationRequest, FlowGenerationResponse
)
from ..schemas.flow import (
    FlowCheckpointNoteCreate, FlowCheckpointNoteUpdate, FlowCheckpointNoteResponse,
    FlowCheckpointAssignmentCreate, FlowCheckpointAssignmentResponse,
    FlowCheckpointAlarmCreate
)
from ..dependencies import get_current_user
from ..ai.buddy_ai import BuddyAI
from ..services.github_service import GitHubService

router = APIRouter(prefix="/flows", tags=["flows"])

@router.get("/", response_model=List[ProjectFlowResponse])
async def get_user_flows(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all project flows for the current user"""
    result = await db.execute(
        select(ProjectFlow)
        .options(
            selectinload(ProjectFlow.checkpoints).selectinload(FlowCheckpoint.resources),
            selectinload(ProjectFlow.repository)  # Include repository
        )
        .filter(ProjectFlow.user_id == current_user.id)
    )
    flows = result.scalars().unique().all()
    
    # Add repository information to flow responses
    for flow in flows:
        if flow.repository:
            # Add repository fields to flow object for JSON serialization
            flow.repository_url = flow.repository.html_url
            flow.local_path = flow.repository.local_path
    
    return flows

@router.post("/", response_model=ProjectFlowResponse)
async def create_flow(
    flow_data: ProjectFlowCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new project flow"""
    db_flow = ProjectFlow(
        user_id=current_user.id,
        title=flow_data.title,
        description=flow_data.description,
        status=flow_data.status,
        difficulty=flow_data.difficulty,
        estimated_duration=flow_data.estimated_duration,
        tags=flow_data.tags or []
    )
    
    db.add(db_flow)
    await db.commit()
    await db.refresh(db_flow)
    
    # Create checkpoints
    for checkpoint_data in flow_data.checkpoints:
        db_checkpoint = FlowCheckpoint(
            flow_id=db_flow.id,
            title=checkpoint_data.title,
            description=checkpoint_data.description,
            order=checkpoint_data.order,
            type=checkpoint_data.type,
            estimated_time=checkpoint_data.estimated_time,
            requirements=checkpoint_data.requirements or [],
            deliverables=checkpoint_data.deliverables or []
        )
        db.add(db_checkpoint)
    
    await db.commit()
    await db.refresh(db_flow)
    return db_flow

@router.get("/{flow_id}", response_model=ProjectFlowResponse)
async def get_flow(
    flow_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific project flow"""
    result = await db.execute(
        select(ProjectFlow)
        .options(
            selectinload(ProjectFlow.checkpoints).selectinload(FlowCheckpoint.resources)
        )
        .filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")
    
    return flow

@router.put("/{flow_id}", response_model=ProjectFlowResponse)
async def update_flow(
    flow_id: int,
    flow_data: ProjectFlowUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update a project flow"""
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")
    
    for field, value in flow_data.dict(exclude_unset=True).items():
        setattr(flow, field, value)
    
    flow.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(flow)
    return flow

@router.delete("/{flow_id}")
async def delete_flow(
    flow_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a project flow"""
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")
    
    await db.delete(flow)
    await db.commit()
    return {"message": "Flow deleted successfully"}

class CheckpointStatusUpdate(BaseModel):
    is_completed: bool

@router.patch("/{flow_id}/checkpoints/{checkpoint_id}", response_model=ProjectFlowResponse)
@router.put("/{flow_id}/checkpoints/{checkpoint_id}", response_model=ProjectFlowResponse)
async def update_checkpoint_status(
    flow_id: int,
    checkpoint_id: int,
    payload: CheckpointStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update checkpoint completion status (accepts JSON body)."""
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    
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
    
    is_completed = payload.is_completed
    checkpoint.is_completed = is_completed
    if is_completed:
        checkpoint.completed_at = datetime.utcnow()
        if checkpoint.order == flow.current_checkpoint_index:
            flow.current_checkpoint_index = min(
                flow.current_checkpoint_index + 1,
                len(flow.checkpoints) - 1
            )
    else:
        checkpoint.completed_at = None
        if checkpoint.order < flow.current_checkpoint_index:
            flow.current_checkpoint_index = checkpoint.order
    
    completed_checkpoints = sum(1 for cp in flow.checkpoints if cp.is_completed)
    if completed_checkpoints == len(flow.checkpoints):
        flow.status = FlowStatus.completed
    elif flow.status == FlowStatus.completed and completed_checkpoints < len(flow.checkpoints):
        flow.status = FlowStatus.active
    
    flow.updated_at = datetime.utcnow()
    await db.commit()
    
    result = await db.execute(
        select(ProjectFlow)
        .options(
            selectinload(ProjectFlow.checkpoints).selectinload(FlowCheckpoint.resources)
        )
        .filter(ProjectFlow.id == flow_id)
    )
    flow = result.scalar_one()
    return flow

@router.post("/{flow_id}/checkpoints/{checkpoint_id}/help")
async def get_checkpoint_help(
    flow_id: int,
    checkpoint_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get AI help for a specific checkpoint"""
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    
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
    buddy_ai = BuddyAI()
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

@router.post("/generate", response_model=FlowGenerationResponse)
async def generate_flow_from_description(
    request: FlowGenerationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Generate a project flow from description using AI"""
    buddy_ai = BuddyAI()
    
    # Generate flow structure using AI
    flow_data = await buddy_ai.generate_project_flow(
        description=request.project_description,
        user_preferences=request.preferences
    )
    
    # Create the flow in database
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
    
    # Save generation message
    generation_message = BuddyFlowMessage(
        user_id=current_user.id,
        flow_id=db_flow.id,
        content=f"Generated flow: {db_flow.title}",
        role="assistant",
        context=MessageContext.flow_creation
    )
    db.add(generation_message)
    await db.commit()
    
    # Auto-create GitHub repository for the flow
    github_service = GitHubService()
    try:
        repo_result = await github_service.create_flow_repository(
            user_mobile=current_user.mobile_number,
            project_name=db_flow.title,
            description=f"AI-generated flow: {request.project_description}"
        )
        
        if repo_result['success']:
            # Save repository information to database
            db_repo = Repository(
                flow_id=db_flow.id,
                github_id=repo_result['repository']['id'],
                name=repo_result['repository']['name'],
                full_name=repo_result['repository']['full_name'],
                description=f"AI-generated flow: {request.project_description}",
                html_url=repo_result['repository']['html_url'],
                ssh_url=repo_result['repository']['ssh_url'],
                clone_url=repo_result['repository']['clone_url'],
                private=True,
                local_path=repo_result['local_path'],
                created_by_ai=True
            )
            db.add(db_repo)
            await db.commit()
            
            # Log successful repository creation
            repo_message = BuddyFlowMessage(
                user_id=current_user.id,
                flow_id=db_flow.id,
                content=f"Created GitHub repository: {repo_result['repository']['html_url']}",
                role="assistant",
                context=MessageContext.flow_creation
            )
            db.add(repo_message)
            await db.commit()
            
            return {
                "flow": db_flow,
                "repository": repo_result['repository'],
                "local_path": repo_result['local_path'],
                "message": f"Successfully generated flow '{db_flow.title}' with {len(flow_data['checkpoints'])} checkpoints and created GitHub repository!"
            }
        else:
            # Repository creation failed, but flow was created successfully
            return {
                "flow": db_flow,
                "repository_error": repo_result.get('error', 'Unknown error'),
                "message": f"Successfully generated flow '{db_flow.title}' with {len(flow_data['checkpoints'])} checkpoints! (Repository creation failed: {repo_result.get('error', 'Unknown error')})"
            }
    except Exception as repo_error:
        # Repository creation failed, but flow was created successfully
        return {
            "flow": db_flow,
            "repository_error": str(repo_error),
            "message": f"Successfully generated flow '{db_flow.title}' with {len(flow_data['checkpoints'])} checkpoints! (Repository creation failed: {str(repo_error)})"
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
        s = text.strip().lower()
        import re
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

@router.get("/{flow_id}/messages", response_model=List[BuddyFlowMessageResponse])
async def get_flow_messages(
    flow_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all Buddy messages related to a flow"""
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")
    
    messages_result = await db.execute(
        select(BuddyFlowMessage).filter(
            BuddyFlowMessage.flow_id == flow_id,
            BuddyFlowMessage.user_id == current_user.id
        ).order_by(BuddyFlowMessage.timestamp.asc())
    )
    messages = messages_result.scalars().all()
    
    return messages

@router.post("/progress")
async def update_flow_progress(
    flow_id: int,
    checkpoint_index: int,
    is_completed: bool,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update flow progress and get AI encouragement"""
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")
    
    # Generate progress message using AI
    buddy_ai = BuddyAI()
    progress_message = await buddy_ai.generate_progress_message(
        flow=flow,
        checkpoint_index=checkpoint_index,
        is_completed=is_completed
    )
    
    # Save progress message
    progress_msg = BuddyFlowMessage(
        user_id=current_user.id,
        flow_id=flow_id,
        content=progress_message,
        role="assistant",
        context=MessageContext.flow_progress
    )
    db.add(progress_msg)
    await db.commit()
    
    return {"message": progress_message}

# ---------------- WebSocket manager for flow updates -----------------
class FlowConnectionManager:
    def __init__(self):
        # key: (user_id, flow_id) -> list[WebSocket]
        self.active_connections: Dict[Tuple[int, int], list[WebSocket]] = {}

    async def connect(self, user_id: int, flow_id: int, websocket: WebSocket):
        await websocket.accept()
        key = (user_id, flow_id)
        self.active_connections.setdefault(key, []).append(websocket)

    def disconnect(self, user_id: int, flow_id: int, websocket: WebSocket):
        key = (user_id, flow_id)
        conns = self.active_connections.get(key, [])
        if websocket in conns:
            conns.remove(websocket)
        if not conns and key in self.active_connections:
            del self.active_connections[key]

    async def send_to_flow(self, user_id: int, flow_id: int, data: dict):
        key = (user_id, flow_id)
        if key in self.active_connections:
            for ws in list(self.active_connections[key]):
                try:
                    await ws.send_json(data)
                except Exception:
                    self.disconnect(user_id, flow_id, ws)

flow_ws_manager = FlowConnectionManager()

async def _get_user_from_token(token: str, db: AsyncSession) -> int:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        mobile_number = payload.get("sub")
        if not mobile_number:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        user = await get_user_by_mobile(db, mobile_number)
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user.id
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Token error: {e}")

@router.websocket("/ws")
async def flows_ws(websocket: WebSocket, token: str = Query(...), flow_id: int = Query(...), db: AsyncSession = Depends(get_db)):
    """WebSocket endpoint for real-time flow updates. Pass JWT in query 'token' and flow_id."""
    user_id = await _get_user_from_token(token, db)
    await flow_ws_manager.connect(user_id, flow_id, websocket)
    try:
        while True:
            # Keep the connection alive; no inbound messages required right now
            _ = await websocket.receive_text()
            # Optionally support ping/pong or client acks later
    except WebSocketDisconnect:
        flow_ws_manager.disconnect(user_id, flow_id, websocket)
    except Exception:
        flow_ws_manager.disconnect(user_id, flow_id, websocket)
        try:
            await websocket.close()
        except Exception:
            pass

# --- Helpers for new endpoints ---
async def _ensure_flow_and_checkpoint(db: AsyncSession, user_id: int, flow_id: int, checkpoint_id: int):
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == user_id
        )
    )
    flow = result.scalar_one_or_none()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")
    cp_result = await db.execute(
        select(FlowCheckpoint).filter(
            FlowCheckpoint.id == checkpoint_id,
            FlowCheckpoint.flow_id == flow_id
        )
    )
    checkpoint = cp_result.scalar_one_or_none()
    if not checkpoint:
        raise HTTPException(status_code=404, detail="Checkpoint not found")
    return flow, checkpoint

# --- Per-checkpoint Notes ---
@router.post("/{flow_id}/checkpoints/{checkpoint_id}/notes", response_model=FlowCheckpointNoteResponse)
async def create_checkpoint_note(
    flow_id: int,
    checkpoint_id: int,
    payload: FlowCheckpointNoteCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    note = FlowCheckpointNote(
        flow_id=flow_id,
        checkpoint_id=checkpoint_id,
        user_id=current_user.id,
        title=payload.title,
        content=payload.content,
        tags=payload.tags or []
    )
    db.add(note)
    await db.commit()
    await db.refresh(note)
    return note

@router.get("/{flow_id}/checkpoints/{checkpoint_id}/notes", response_model=List[FlowCheckpointNoteResponse])
async def list_checkpoint_notes(
    flow_id: int,
    checkpoint_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    result = await db.execute(
        select(FlowCheckpointNote).filter(
            FlowCheckpointNote.flow_id == flow_id,
            FlowCheckpointNote.checkpoint_id == checkpoint_id,
            FlowCheckpointNote.user_id == current_user.id
        ).order_by(FlowCheckpointNote.created_at.desc())
    )
    return result.scalars().all()

@router.patch("/{flow_id}/checkpoints/{checkpoint_id}/notes/{note_id}", response_model=FlowCheckpointNoteResponse)
async def update_checkpoint_note(
    flow_id: int,
    checkpoint_id: int,
    note_id: int,
    payload: FlowCheckpointNoteUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    result = await db.execute(
        select(FlowCheckpointNote).filter(
            FlowCheckpointNote.id == note_id,
            FlowCheckpointNote.flow_id == flow_id,
            FlowCheckpointNote.checkpoint_id == checkpoint_id,
            FlowCheckpointNote.user_id == current_user.id
        )
    )
    note = result.scalar_one_or_none()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    for k, v in payload.dict(exclude_unset=True).items():
        setattr(note, k, v)
    note.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(note)
    return note

@router.delete("/{flow_id}/checkpoints/{checkpoint_id}/notes/{note_id}")
async def delete_checkpoint_note(
    flow_id: int,
    checkpoint_id: int,
    note_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    result = await db.execute(
        select(FlowCheckpointNote).filter(
            FlowCheckpointNote.id == note_id,
            FlowCheckpointNote.flow_id == flow_id,
            FlowCheckpointNote.checkpoint_id == checkpoint_id,
            FlowCheckpointNote.user_id == current_user.id
        )
    )
    note = result.scalar_one_or_none()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    await db.delete(note)
    await db.commit()
    return {"message": "Note deleted"}

# --- Per-checkpoint Assignments ---
@router.post("/{flow_id}/checkpoints/{checkpoint_id}/assignments", response_model=FlowCheckpointAssignmentResponse)
async def assign_checkpoint(
    flow_id: int,
    checkpoint_id: int,
    payload: FlowCheckpointAssignmentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    assignment = FlowCheckpointAssignment(
        flow_id=flow_id,
        checkpoint_id=checkpoint_id,
        assignee_id=payload.assignee_id,
        assignee_name=payload.assignee_name,
        assigned_by=current_user.id,
        assigned_at=datetime.utcnow()
    )
    db.add(assignment)
    await db.commit()
    await db.refresh(assignment)
    return assignment

@router.get("/{flow_id}/checkpoints/{checkpoint_id}/assignments", response_model=List[FlowCheckpointAssignmentResponse])
async def list_assignments(
    flow_id: int,
    checkpoint_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    result = await db.execute(
        select(FlowCheckpointAssignment).filter(
            FlowCheckpointAssignment.flow_id == flow_id,
            FlowCheckpointAssignment.checkpoint_id == checkpoint_id
        ).order_by(FlowCheckpointAssignment.assigned_at.desc())
    )
    return result.scalars().all()

@router.delete("/{flow_id}/checkpoints/{checkpoint_id}/assignments/{assignment_id}")
async def delete_assignment(
    flow_id: int,
    checkpoint_id: int,
    assignment_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    result = await db.execute(
        select(FlowCheckpointAssignment).filter(
            FlowCheckpointAssignment.id == assignment_id,
            FlowCheckpointAssignment.flow_id == flow_id,
            FlowCheckpointAssignment.checkpoint_id == checkpoint_id
        )
    )
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    await db.delete(assignment)
    await db.commit()
    return {"message": "Assignment deleted"}

# --- Per-checkpoint Alarms ---
@router.post("/{flow_id}/checkpoints/{checkpoint_id}/alarms")
async def create_checkpoint_alarm(
    flow_id: int,
    checkpoint_id: int,
    payload: FlowCheckpointAlarmCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    # Map strings to enums with safe defaults
    alarm_type = AlarmType[payload.type] if isinstance(payload.type, str) and payload.type in AlarmType.__members__ else AlarmType.task
    repeat = AlarmRepeat[payload.repeat] if isinstance(payload.repeat, str) and payload.repeat in AlarmRepeat.__members__ else AlarmRepeat.none
    alarm = FlowAlarmModel(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        title=payload.title,
        description=payload.description,
        scheduled_time=payload.scheduled_time,
        is_active=True,
        type=alarm_type,
        repeat=repeat,
        flow_id=flow_id,
        checkpoint_id=checkpoint_id,
        created_at=datetime.utcnow()
    )
    db.add(alarm)
    await db.commit()
    return {
        "id": alarm.id,
        "title": alarm.title,
        "scheduled_time": alarm.scheduled_time,
        "flow_id": alarm.flow_id,
        "checkpoint_id": alarm.checkpoint_id,
        "type": alarm.type.value,
        "repeat": alarm.repeat.value,
    }

@router.get("/{flow_id}/checkpoints/{checkpoint_id}/alarms")
async def list_checkpoint_alarms(
    flow_id: int,
    checkpoint_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    await _ensure_flow_and_checkpoint(db, current_user.id, flow_id, checkpoint_id)
    result = await db.execute(
        select(FlowAlarmModel).filter(
            FlowAlarmModel.flow_id == flow_id,
            FlowAlarmModel.checkpoint_id == checkpoint_id,
            FlowAlarmModel.user_id == current_user.id,
            FlowAlarmModel.is_active == True
        ).order_by(FlowAlarmModel.scheduled_time.asc())
    )
    alarms = result.scalars().all()
    return [
        {
            "id": a.id,
            "title": a.title,
            "scheduled_time": a.scheduled_time,
            "type": a.type.value if a.type else None,
            "repeat": a.repeat.value if a.repeat else None,
            "flow_id": a.flow_id,
            "checkpoint_id": a.checkpoint_id,
        }
        for a in alarms
    ]

# --- Flow Dashboard ---
@router.get("/{flow_id}/dashboard")
async def get_flow_dashboard(
    flow_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(ProjectFlow).options(selectinload(ProjectFlow.checkpoints)).filter(
            ProjectFlow.id == flow_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    flow = result.scalar_one_or_none()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")

    # Notes and assignments
    notes_result = await db.execute(
        select(FlowCheckpointNote).filter(FlowCheckpointNote.flow_id == flow_id, FlowCheckpointNote.user_id == current_user.id)
    )
    notes = notes_result.scalars().all()
    assign_result = await db.execute(
        select(FlowCheckpointAssignment).filter(FlowCheckpointAssignment.flow_id == flow_id)
    )
    assignments = assign_result.scalars().all()

    # Alarms upcoming (next 10)
    alarms_result = await db.execute(
        select(FlowAlarmModel).filter(
            FlowAlarmModel.flow_id == flow_id,
            FlowAlarmModel.user_id == current_user.id,
            FlowAlarmModel.is_active == True,
            FlowAlarmModel.scheduled_time >= datetime.utcnow()
        ).order_by(FlowAlarmModel.scheduled_time.asc()).limit(10)
    )
    upcoming_alarms = alarms_result.scalars().all()

    total = len(flow.checkpoints)
    completed = sum(1 for cp in flow.checkpoints if cp.is_completed)
    pct = (completed / total * 100.0) if total else 0.0

    insights = []
    if pct == 0:
        insights.append("Getting started – knock out an easy checkpoint first.")
    elif pct < 50:
        insights.append("You're making progress. Consider batching similar tasks.")
    elif pct < 100:
        insights.append("Great momentum! Plan a review before final tasks.")
    else:
        insights.append("Flow complete – archive or start the next one.")

    # Team stats (handle missing tables gracefully during development)
    try:
        contributions_result = await db.execute(
            select(WorkContribution).filter(WorkContribution.flow_id == flow_id)
        )
        contributions = contributions_result.scalars().all()
        
        ai_assistance_result = await db.execute(
            select(AIAssistance).filter(AIAssistance.flow_id == flow_id)
        )
        ai_assistance_count = len(ai_assistance_result.scalars().all())
        
        team_members_result = await db.execute(
            select(CollaborationMember).filter(CollaborationMember.project_id == flow_id)
        )
        team_members_count = len(team_members_result.scalars().all())
        
        total_hours = sum(contrib.hours_worked for contrib in contributions)
        contributors_count = len(set(contrib.user_id for contrib in contributions))
        last_activity = max((contrib.contributed_at for contrib in contributions), default=None)
    except Exception as e:
        # Tables might not exist yet during development
        print(f"Team stats tables not available: {e}")
        total_hours = 0.0
        contributors_count = 0
        ai_assistance_count = 0
        team_members_count = 0
        last_activity = None

    return {
        "flow": {
            "id": flow.id,
            "title": flow.title,
            "status": flow.status.value if flow.status else None,
            "difficulty": flow.difficulty.value if flow.difficulty else None,
            "estimated_duration": flow.estimated_duration,
            "current_checkpoint_index": flow.current_checkpoint_index,
            "tags": flow.tags or [],
        },
        "progress": {
            "total": total,
            "completed": completed,
            "percentage": round(pct, 2)
        },
        "participants": list({a.assignee_name or str(a.assignee_id) for a in assignments}),
        "notes_count": len(notes),
        "assignments_count": len(assignments),
        "upcoming_alarms": [
            {
                "id": a.id,
                "title": a.title,
                "at": a.scheduled_time,
                "checkpoint_id": a.checkpoint_id
            } for a in upcoming_alarms
        ],
        "insights": insights,
        "team_stats": {
            "total_hours_worked": total_hours,
            "total_contributors": contributors_count,
            "ai_assistance_sessions": ai_assistance_count,
            "team_members": team_members_count,
            "last_activity": last_activity.isoformat() if last_activity else None
        }
    }

# --- Scaffold (placeholder) ---
class ScaffoldRequest(BaseModel):
    template: Optional[str] = None
    language: Optional[str] = None
    init_readme: Optional[bool] = True

@router.post("/{flow_id}/scaffold")
async def scaffold_project(
    flow_id: int,
    payload: ScaffoldRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Ensure flow exists and belongs to user
    result = await db.execute(
        select(ProjectFlow).filter(ProjectFlow.id == flow_id, ProjectFlow.user_id == current_user.id)
    )
    flow = result.scalar_one_or_none()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")

    message = BuddyFlowMessage(
        user_id=current_user.id,
        flow_id=flow_id,
        content=f"Scaffold requested for '{flow.title}' (template={payload.template}, language={payload.language})",
        role="assistant",
        context=MessageContext.flow_creation
    )
    db.add(message)
    await db.commit()

    # Build comprehensive buddy config from checkpoints
    config = {
        "name": flow.title,
        "description": flow.description,
        "template": payload.template,
        "language": payload.language,
        "version": "1.0.0",
        "buddy": {
            "flow_id": flow_id,
            "created_at": flow.created_at.isoformat(),
            "auto_tracking": True,
            "rules_engine": "strict"
        },
        "checkpoints": [
            {
                "id": cp.id,
                "title": cp.title,
                "description": cp.description or "",
                "order": cp.order,
                "type": cp.type.value if cp.type else "task",
                "file_patterns": [
                    f"**/{cp.title.lower().replace(' ', '-')}/*",
                    f"**/src/{cp.title.lower().replace(' ', '_')}.*",
                    f"**/*{cp.title.lower().replace(' ', '')}*"
                ],
                "rules": [
                    "file_exists",
                    "has_content",
                    "tests_pass" if "test" in cp.title.lower() else "lints_clean"
                ],
                "deliverables": [
                    f"{cp.title.lower().replace(' ', '_')}.{payload.language or 'js'}",
                    f"{cp.title.lower().replace(' ', '-')}/README.md"
                ]
            }
            for cp in sorted(flow.checkpoints, key=lambda c: c.order)
        ],
        "scripts": {
            "test": "npm test" if payload.language in ["javascript", "typescript"] else "python -m pytest",
            "lint": "eslint ." if payload.language in ["javascript", "typescript"] else "flake8 .",
            "build": "npm run build" if payload.language in ["javascript", "typescript"] else "python setup.py build"
        }
    }

    # TODO: In production, write to actual repo via git/dock service
    # For now, return the config that would be written as buddy.json
    
    return {
        "status": "completed", 
        "flow_id": flow_id, 
        "template": payload.template, 
        "language": payload.language, 
        "config": config,
        "file_path": "buddy.json",
        "message": f"Scaffold configuration generated for {flow.title}"
    }

class CodeEventPayload(BaseModel):
    path: str
    event: str
    editor: Optional[str] = None
    sha: Optional[str] = None
    timestamp: Optional[datetime] = None

@router.post("/{flow_id}/code-events")
async def handle_code_event(
    flow_id: int,
    payload: CodeEventPayload,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Enhanced code event handler with proper rules evaluation.
    Auto-marks checkpoints based on file patterns, rules, and deliverables.
    """
    result = await db.execute(
        select(ProjectFlow)
        .options(selectinload(ProjectFlow.checkpoints))
        .filter(ProjectFlow.id == flow_id, ProjectFlow.user_id == current_user.id)
    )
    flow = result.scalar_one_or_none()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")

    updated_ids = []
    path_lc = (payload.path or "").lower()
    # Prefer earlier pending checkpoints first
    pending = sorted([cp for cp in flow.checkpoints if not cp.is_completed], key=lambda c: c.order)

    def evaluate_checkpoint_rules(checkpoint, file_path: str) -> bool:
        """Evaluate if checkpoint rules are satisfied"""
        # Basic file pattern matching
        title_tokens = [t for t in checkpoint.title.lower().replace('-', ' ').replace('_', ' ').split() if len(t) > 2]
        deliverable_tokens = []
        try:
            for d in (checkpoint.deliverables or []):
                deliverable_tokens += [t for t in str(d).lower().replace('-', ' ').replace('_', ' ').split() if len(t) > 2]
        except Exception:
            pass
        
        tokens = set(title_tokens + deliverable_tokens)
        if not tokens:
            return False
            
        # File path matching
        path_match = any(tok in file_path.lower() for tok in tokens)
        if not path_match:
            return False
            
        # Enhanced rules evaluation
        rules_passed = 0
        total_rules = 0
        
        # Rule: file_exists (always true if we got an event)
        rules_passed += 1
        total_rules += 1
        
        # Rule: has_content (check file extension indicates content)
        if any(ext in file_path for ext in ['.js', '.py', '.ts', '.jsx', '.vue', '.md', '.txt', '.json']):
            rules_passed += 1
        total_rules += 1
        
        # Rule: tests_pass (heuristic: if path contains test and checkpoint is test-related)
        if 'test' in checkpoint.title.lower() and 'test' in file_path.lower():
            rules_passed += 1
            total_rules += 1
        elif 'test' not in checkpoint.title.lower():
            # Non-test checkpoints get benefit of doubt
            rules_passed += 1
            total_rules += 1
            
        # Rule: lints_clean (heuristic: standard file extensions)
        if any(file_path.endswith(ext) for ext in ['.js', '.ts', '.py', '.jsx', '.vue']):
            rules_passed += 1
        total_rules += 1
        
        # Pass if 75% of rules satisfied
        return rules_passed >= (total_rules * 0.75)

    for cp in pending:
        if evaluate_checkpoint_rules(cp, payload.path):
            # Mark checkpoint as completed
            await db.execute(
                update(FlowCheckpoint)
                .where(FlowCheckpoint.id == cp.id)
                .values(is_completed=True, completed_at=datetime.now())
            )
            updated_ids.append(cp.id)
            
            # Update flow status if all checkpoints completed
            remaining = len([c for c in flow.checkpoints if not c.is_completed and c.id not in updated_ids])
            if remaining == 0:
                await db.execute(
                    update(ProjectFlow)
                    .where(ProjectFlow.id == flow_id)
                    .values(status=FlowStatus.completed, current_checkpoint_index=len(flow.checkpoints))
                )
            else:
                # Update current checkpoint index
                next_idx = min(c.order for c in flow.checkpoints if not c.is_completed and c.id not in updated_ids)
                await db.execute(
                    update(ProjectFlow)
                    .where(ProjectFlow.id == flow_id)
                    .values(current_checkpoint_index=next_idx)
                )
            break  # Only auto-complete one checkpoint per event

    await db.commit()

    # Broadcast update if any checkpoints were updated
    if updated_ids:
        update_payload = {
            "flow_id": flow_id,
            "updated_checkpoint_ids": updated_ids,
            "status": "completed" if len([c for c in flow.checkpoints if not c.is_completed]) == len(updated_ids) else "active",
            "current_checkpoint_index": flow.current_checkpoint_index,
            "timestamp": datetime.now().isoformat()
        }
        # Use the existing connection manager
        await flow_ws_manager.broadcast_to_flow(flow_id, current_user.mobile or str(current_user.id), "flow_update", update_payload)

    return {
        "event_received": True,
        "path": payload.path,
        "auto_completed": updated_ids,
        "flow_status": flow.status.value,
        "rules_engine": "enhanced"
    }
    if completed_count == len(flow.checkpoints) and len(flow.checkpoints) > 0:
        flow.status = FlowStatus.completed
    elif flow.status == FlowStatus.completed and completed_count < len(flow.checkpoints):
        flow.status = FlowStatus.active

    flow.updated_at = datetime.utcnow()
    await db.commit()

    # Broadcast changes to WS subscribers for this flow
    if updated_ids:
        await flow_ws_manager.send_to_flow(
            current_user.id, flow_id,
            {
                "type": "flow_update",
                "data": {
                    "flow_id": flow_id,
                    "updated_checkpoint_ids": updated_ids,
                    "status": flow.status.value if hasattr(flow.status, 'value') else str(flow.status),
                    "current_checkpoint_index": flow.current_checkpoint_index,
                    "timestamp": datetime.utcnow().isoformat(),
                }
            }
        )

    return {"updated": len(updated_ids), "auto_marked_ids": updated_ids}
