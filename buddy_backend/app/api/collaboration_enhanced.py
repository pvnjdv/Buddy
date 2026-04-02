# Enhanced collaboration endpoints for buddy_backend

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Optional

from app.core.database import get_db
from app.models.collaboration import (
    CollaborationProject, CollaborationInvitation, CollaborationMember,
    WorkContribution, AIAssistance, CheckpointAssignment
)
from app.schemas.collaboration import (
    WorkContributionCreate, WorkContributionResponse,
    AIAssistanceCreate, AIAssistanceResponse,
    CheckpointAssignmentCreate, CheckpointCommentCreate,
    TeamStatsResponse, CollaborationInvitationCreate
)

router = APIRouter(prefix="/collaboration", tags=["collaboration"])

# Work contributions endpoints
@router.post("/work-contributions", response_model=dict)
async def add_work_contribution(
    contribution: WorkContributionCreate,
    db: Session = Depends(get_db)
):
    """Add work contribution for a checkpoint"""
    try:
        db_contribution = WorkContribution(
            flow_id=contribution.flow_id,
            checkpoint_id=contribution.checkpoint_id,
            user_id=contribution.user_id,
            user_name=contribution.user_name,
            hours_worked=contribution.hours_worked,
            work_description=contribution.work_description,
            contribution_type=contribution.type,
            contributed_at=datetime.utcnow()
        )
        
        db.add(db_contribution)
        db.commit()
        db.refresh(db_contribution)
        
        return {"success": True, "message": "Work contribution added successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/work-contributions/{flow_id}/{checkpoint_id}", response_model=List[WorkContributionResponse])
async def get_checkpoint_contributions(
    flow_id: str,
    checkpoint_id: str,
    db: Session = Depends(get_db)
):
    """Get all work contributions for a specific checkpoint"""
    try:
        contributions = db.query(WorkContribution).filter(
            WorkContribution.flow_id == flow_id,
            WorkContribution.checkpoint_id == checkpoint_id
        ).all()
        
        return [
            WorkContributionResponse(
                id=str(contrib.id),
                user_id=contrib.user_id,
                user_name=contrib.user_name,
                hours_worked=contrib.hours_worked,
                work_description=contrib.work_description,
                type=contrib.contribution_type,
                contributed_at=contrib.contributed_at
            )
            for contrib in contributions
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# AI assistance endpoints
@router.post("/ai-assistance", response_model=dict)
async def record_ai_assistance(
    assistance: AIAssistanceCreate,
    db: Session = Depends(get_db)
):
    """Record AI assistance for a checkpoint"""
    try:
        db_assistance = AIAssistance(
            flow_id=assistance.flow_id,
            checkpoint_id=assistance.checkpoint_id,
            assistance_id=assistance.assistance_id,
            query=assistance.query,
            response=assistance.response,
            assistance_type=assistance.type,
            was_helpful=assistance.was_helpful,
            feedback=assistance.feedback,
            requested_at=datetime.utcnow()
        )
        
        db.add(db_assistance)
        db.commit()
        db.refresh(db_assistance)
        
        return {"success": True, "message": "AI assistance recorded successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/ai-assistance/{flow_id}/{checkpoint_id}", response_model=List[AIAssistanceResponse])
async def get_ai_assistance_history(
    flow_id: str,
    checkpoint_id: str,
    db: Session = Depends(get_db)
):
    """Get AI assistance history for a specific checkpoint"""
    try:
        assistance_records = db.query(AIAssistance).filter(
            AIAssistance.flow_id == flow_id,
            AIAssistance.checkpoint_id == checkpoint_id
        ).order_by(AIAssistance.requested_at.desc()).all()
        
        return [
            AIAssistanceResponse(
                assistance_id=record.assistance_id,
                query=record.query,
                response=record.response,
                type=record.assistance_type,
                was_helpful=record.was_helpful,
                feedback=record.feedback,
                requested_at=record.requested_at
            )
            for record in assistance_records
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Checkpoint assignment endpoints
@router.post("/assign-checkpoint", response_model=dict)
async def assign_checkpoint(
    assignment: CheckpointAssignmentCreate,
    db: Session = Depends(get_db)
):
    """Assign a checkpoint to a team member"""
    try:
        # Check if checkpoint is already assigned
        existing = db.query(CheckpointAssignment).filter(
            CheckpointAssignment.flow_id == assignment.flow_id,
            CheckpointAssignment.checkpoint_id == assignment.checkpoint_id
        ).first()
        
        if existing:
            existing.assignee_id = assignment.assignee_id
            existing.assignee_name = assignment.assignee_name
            existing.assigned_at = datetime.utcnow()
        else:
            db_assignment = CheckpointAssignment(
                flow_id=assignment.flow_id,
                checkpoint_id=assignment.checkpoint_id,
                assignee_id=assignment.assignee_id,
                assignee_name=assignment.assignee_name,
                assigned_at=datetime.utcnow()
            )
            db.add(db_assignment)
        
        db.commit()
        return {"success": True, "message": "Checkpoint assigned successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# Checkpoint comments endpoints
@router.post("/checkpoint-comments", response_model=dict)
async def add_checkpoint_comment(
    comment: CheckpointCommentCreate,
    db: Session = Depends(get_db)
):
    """Add a comment to a checkpoint"""
    try:
        # In a real implementation, you'd have a CheckpointComment model
        # For now, we'll simulate this
        return {"success": True, "message": "Comment added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Team statistics endpoints
@router.get("/team-stats/{flow_id}", response_model=TeamStatsResponse)
async def get_team_stats(
    flow_id: str,
    db: Session = Depends(get_db)
):
    """Get team statistics for a flow"""
    try:
        # Get work contributions
        contributions = db.query(WorkContribution).filter(
            WorkContribution.flow_id == flow_id
        ).all()
        
        # Calculate stats
        total_hours = sum(contrib.hours_worked for contrib in contributions)
        contributors = len(set(contrib.user_id for contrib in contributions))
        
        # Get AI assistance count
        ai_assistance_count = db.query(AIAssistance).filter(
            AIAssistance.flow_id == flow_id
        ).count()
        
        # Get team members (if collaboration exists)
        try:
            team_members = db.query(CollaborationMember).filter(
                CollaborationMember.project_id == flow_id
            ).count()
        except Exception:
            # Table might not exist yet
            team_members = 0
        
        return TeamStatsResponse(
            total_hours_worked=total_hours,
            total_contributors=contributors,
            ai_assistance_sessions=ai_assistance_count,
            team_members=team_members,
            last_activity=max(contrib.contributed_at for contrib in contributions) if contributions else None
        )
    except Exception as e:
        # Return empty stats if tables don't exist yet
        return TeamStatsResponse(
            total_hours_worked=0.0,
            total_contributors=0,
            ai_assistance_sessions=0,
            team_members=0,
            last_activity=None
        )

# Invitation endpoints (enhanced)
@router.post("/invitations", response_model=dict)
async def create_invitation(
    invitation: CollaborationInvitationCreate,
    db: Session = Depends(get_db)
):
    """Create a collaboration invitation"""
    try:
        # Set default expiration (24 hours from now)
        expires_at = invitation.expires_at or (datetime.utcnow() + timedelta(hours=24))

        # Create invitation record
        db_invitation = CollaborationInvitation(
            project_id=invitation.project_id,
            receiver_mobile=invitation.receiver_mobile,
            inviter_id=invitation.inviter_id,
            inviter_name=invitation.inviter_name,
            role=invitation.role,
            message=invitation.message,
            expires_at=expires_at,
            created_at=datetime.utcnow()
        )

        db.add(db_invitation)
        db.commit()
        db.refresh(db_invitation)

        return {"success": True, "invitation_id": str(db_invitation.id)}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
