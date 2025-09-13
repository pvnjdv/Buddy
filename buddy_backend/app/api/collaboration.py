# app/api/collaboration.py
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, and_
from sqlalchemy.orm import joinedload, selectinload
from typing import List, Optional
from datetime import datetime, timedelta
import json

from ..core.database import get_db
from ..models.collaboration import (
    ProjectCollaboration, CollaborationMember, CollaborationInvitation, 
    AICollaborationInsight, CollaborationActivity, CollaborationStatus, CollaborationRole
)
from ..schemas.collaboration import (
    CollaborationCreate, CollaborationInvitationCreate, CollaborationInvitationResponse,
    CollaborationProjectSchema, CollaborationInvitationSchema, AICollaborationInsightSchema,
    AIInsightRequest, CollaborationAnalysisSchema
)
from ..models.user import User
from ..models.flow import ProjectFlow
from ..dependencies import get_current_user
from ..ai.buddy_ai import BuddyAI

router = APIRouter(prefix="/collaboration", tags=["collaboration"])

# Pydantic schemas
from pydantic import BaseModel

class CollaborationCreate(BaseModel):
    project_id: int
    name: str
    description: Optional[str] = None
    settings: Optional[dict] = {}

class CollaborationResponse(BaseModel):
    id: str
    project_id: int
    name: str
    description: Optional[str]
    status: str
    member_count: int
    created_at: datetime
    
class InvitationCreate(BaseModel):
    collaboration_id: str
    invitee_mobile: str
    role: CollaborationRole = CollaborationRole.contributor
    message: Optional[str] = None

class InvitationResponse(BaseModel):
    id: str
    collaboration_name: str
    inviter_name: str
    role: str
    message: Optional[str]
    invited_at: datetime
    expires_at: Optional[datetime]

class AIInsightResponse(BaseModel):
    id: str
    insight_type: str
    title: str
    content: str
    relevance_score: int
    created_at: datetime

@router.post("/create", response_model=CollaborationResponse)
async def create_collaboration(
    collaboration_data: CollaborationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new collaboration for a project"""
    
    # Verify user owns the project
    result = await db.execute(
        select(ProjectFlow).filter(
            and_(ProjectFlow.id == collaboration_data.project_id,
                 ProjectFlow.user_id == current_user.id)
        )
    )
    project = result.scalar_one_or_none()
    
    if not project:
        raise HTTPException(
            status_code=404, 
            detail="Project not found or access denied"
        )
    
    # Create collaboration
    collaboration = ProjectCollaboration(
        project_id=collaboration_data.project_id,
        owner_id=current_user.id,
        name=collaboration_data.name,
        description=collaboration_data.description,
        settings=collaboration_data.settings
    )
    
    db.add(collaboration)
    await db.commit()
    await db.refresh(collaboration)
    
    # Add owner as first member
    owner_member = CollaborationMember(
        collaboration_id=collaboration.id,
        user_id=current_user.id,
        role=CollaborationRole.owner
    )
    
    db.add(owner_member)
    await db.commit()
    
    return CollaborationResponse(
        id=collaboration.id,
        project_id=collaboration.project_id,
        name=collaboration.name,
        description=collaboration.description,
        status=collaboration.status.value,
        member_count=1,
        created_at=collaboration.created_at
    )

@router.post("/invite", response_model=dict)
async def send_invitation(
    invitation_data: InvitationCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Send collaboration invitation to a user via mobile number"""
    
    # Verify user has permission to invite (owner or admin)
    result = await db.execute(
        select(CollaborationMember).filter(
            and_(CollaborationMember.collaboration_id == invitation_data.collaboration_id,
                 CollaborationMember.user_id == current_user.id,
                 CollaborationMember.role.in_([CollaborationRole.owner, CollaborationRole.admin]))
        )
    )
    member = result.scalar_one_or_none()
    
    if not member:
        raise HTTPException(
            status_code=403,
            detail="Permission denied: Only owners and admins can send invitations"
        )
    
    # Check if invitation already exists
    existing_result = await db.execute(
        select(CollaborationInvitation).filter(
            and_(CollaborationInvitation.collaboration_id == invitation_data.collaboration_id,
                 CollaborationInvitation.invitee_mobile == invitation_data.invitee_mobile,
                 CollaborationInvitation.status == CollaborationStatus.pending)
        )
    )
    
    if existing_result.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="Pending invitation already exists for this mobile number"
        )
    
    # Create invitation
    invitation = CollaborationInvitation(
        collaboration_id=invitation_data.collaboration_id,
        inviter_id=current_user.id,
        invitee_mobile=invitation_data.invitee_mobile,
        role=invitation_data.role,
        message=invitation_data.message,
        expires_at=datetime.utcnow() + timedelta(days=7)  # 7 days expiry
    )
    
    db.add(invitation)
    await db.commit()
    
    # TODO: Send SMS/notification to invitee
    # background_tasks.add_task(send_invitation_sms, invitation_data.invitee_mobile, invitation.id)
    
    return {"message": "Invitation sent successfully", "invitation_id": invitation.id}

@router.get("/invitations", response_model=List[InvitationResponse])
async def get_my_invitations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get pending invitations for current user"""
    
    result = await db.execute(
        select(CollaborationInvitation)
        .options(
            joinedload(CollaborationInvitation.collaboration),
            joinedload(CollaborationInvitation.inviter)
        )
        .filter(
            and_(CollaborationInvitation.invitee_mobile == current_user.mobile_number,
                 CollaborationInvitation.status == CollaborationStatus.pending,
                 CollaborationInvitation.expires_at > datetime.utcnow())
        )
    )
    invitations = result.scalars().unique().all()
    
    return [
        InvitationResponse(
            id=inv.id,
            collaboration_name=inv.collaboration.name,
            inviter_name=inv.inviter.name or inv.inviter.mobile_number,
            role=inv.role.value,
            message=inv.message,
            invited_at=inv.invited_at,
            expires_at=inv.expires_at
        )
        for inv in invitations
    ]

@router.post("/invitations/{invitation_id}/respond")
async def respond_to_invitation(
    invitation_id: str,
    accept: bool,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Accept or reject a collaboration invitation"""
    
    result = await db.execute(
        select(CollaborationInvitation)
        .options(joinedload(CollaborationInvitation.collaboration))
        .filter(
            and_(CollaborationInvitation.id == invitation_id,
                 CollaborationInvitation.invitee_mobile == current_user.mobile_number,
                 CollaborationInvitation.status == CollaborationStatus.pending)
        )
    )
    invitation = result.scalar_one_or_none()
    
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    
    if invitation.expires_at and invitation.expires_at <= datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invitation has expired")
    
    if accept:
        # Add user as collaboration member
        member = CollaborationMember(
            collaboration_id=invitation.collaboration_id,
            user_id=current_user.id,
            role=invitation.role
        )
        db.add(member)
        
        # Update invitation
        invitation.status = CollaborationStatus.accepted
        invitation.invitee_id = current_user.id
    else:
        invitation.status = CollaborationStatus.rejected
    
    invitation.responded_at = datetime.utcnow()
    
    await db.commit()
    
    return {"message": "Invitation " + ("accepted" if accept else "rejected")}

@router.get("/projects/{project_id}/insights", response_model=List[AIInsightResponse])
async def get_ai_insights(
    project_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get AI-generated insights for a collaborative project"""
    
    # Verify user has access to project
    result = await db.execute(
        select(CollaborationMember)
        .join(ProjectCollaboration)
        .filter(
            and_(ProjectCollaboration.project_id == project_id,
                 CollaborationMember.user_id == current_user.id)
        )
    )
    
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Get insights
    insights_result = await db.execute(
        select(AICollaborationInsight)
        .join(ProjectCollaboration)
        .filter(ProjectCollaboration.project_id == project_id)
        .order_by(AICollaborationInsight.relevance_score.desc(),
                 AICollaborationInsight.created_at.desc())
        .limit(10)
    )
    insights = insights_result.scalars().all()
    
    return [
        AIInsightResponse(
            id=insight.id,
            insight_type=insight.insight_type,
            title=insight.title,
            content=insight.content,
            relevance_score=insight.relevance_score,
            created_at=insight.created_at
        )
        for insight in insights
    ]

@router.post("/projects/{project_id}/generate-insights")
async def generate_ai_insights(
    project_id: int,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Generate AI insights for project collaboration"""
    
    # Add background task to generate insights
    background_tasks.add_task(_generate_insights_task, project_id, db)
    
    return {"message": "AI insights generation started"}

async def _generate_insights_task(project_id: int, db: AsyncSession):
    """Background task to generate AI insights"""
    
    # Get project and collaboration data
    result = await db.execute(
        select(ProjectFlow)
        .options(selectinload(ProjectFlow.checkpoints))
        .filter(ProjectFlow.id == project_id)
    )
    project = result.scalar_one_or_none()
    
    if not project:
        return
    
    # Initialize AI
    buddy_ai = BuddyAI()
    
    # Generate insights based on project progress
    insights = await buddy_ai.generate_collaboration_insights(project)
    
    # Save insights to database
    for insight_data in insights:
        insight = AICollaborationInsight(
            collaboration_id=insight_data.get("collaboration_id"),
            insight_type=insight_data.get("type"),
            title=insight_data.get("title"),
            content=insight_data.get("content"),
            relevance_score=insight_data.get("relevance_score", 50)
        )
        db.add(insight)
    
    await db.commit()
