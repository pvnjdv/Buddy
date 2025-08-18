from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from sqlalchemy.orm import joinedload, selectinload
from typing import List, Optional
from datetime import datetime, timedelta
import json
import uuid
from pydantic import BaseModel

from ..core.database import get_db
from ..models.flow import ProjectFlow, FlowCheckpoint, FlowResource, BuddyFlowMessage, FlowStatus, FlowDifficulty, CheckpointType, MessageContext, FlowAlarm as FlowAlarmModel, AlarmType, AlarmRepeat
from ..models.user import User
from ..schemas.flow import (
    ProjectFlowCreate, ProjectFlowUpdate, ProjectFlowResponse,
    FlowCheckpointCreate, FlowCheckpointUpdate, FlowCheckpointResponse,
    BuddyFlowMessageCreate, BuddyFlowMessageResponse,
    FlowGenerationRequest, FlowGenerationResponse
)
from ..dependencies import get_current_user
from ..ai.buddy_ai import BuddyAI

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
            selectinload(ProjectFlow.checkpoints).selectinload(FlowCheckpoint.resources)
        )
        .filter(ProjectFlow.user_id == current_user.id)
    )
    flows = result.scalars().unique().all()
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
    
    return {
        "flow": db_flow,
        "message": f"Successfully generated flow '{db_flow.title}' with {len(flow_data['checkpoints'])} checkpoints!"
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
