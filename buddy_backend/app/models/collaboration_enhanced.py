# Enhanced collaboration database models

from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime

Base = declarative_base()

class WorkContribution(Base):
    """Track individual work contributions on checkpoints"""
    __tablename__ = "work_contributions"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(String, index=True, nullable=False)
    checkpoint_id = Column(String, index=True, nullable=False)
    user_id = Column(String, nullable=False)
    user_name = Column(String, nullable=False)
    hours_worked = Column(Float, nullable=False)
    work_description = Column(Text, nullable=False)
    contribution_type = Column(String, nullable=False)  # development, testing, review, etc.
    contributed_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

class AIAssistance(Base):
    """Track AI Buddy assistance for checkpoints"""
    __tablename__ = "ai_assistance"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(String, index=True, nullable=False)
    checkpoint_id = Column(String, index=True, nullable=False)
    assistance_id = Column(String, unique=True, nullable=False)
    query = Column(Text, nullable=False)
    response = Column(Text, nullable=False)
    assistance_type = Column(String, nullable=False)  # guidance, troubleshooting, etc.
    was_helpful = Column(Boolean, default=False)
    feedback = Column(Text, nullable=True)
    requested_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

class CheckpointAssignment(Base):
    """Track checkpoint assignments to team members"""
    __tablename__ = "checkpoint_assignments"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(String, index=True, nullable=False)
    checkpoint_id = Column(String, index=True, nullable=False)
    assignee_id = Column(String, nullable=False)
    assignee_name = Column(String, nullable=False)
    assigned_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

class CheckpointComment(Base):
    """Store comments on checkpoints from team members"""
    __tablename__ = "checkpoint_comments"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(String, index=True, nullable=False)
    checkpoint_id = Column(String, index=True, nullable=False)
    user_id = Column(String, nullable=False)
    user_name = Column(String, nullable=False)
    comment = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class CollaborationInvitation(Base):
    """Enhanced collaboration invitations with more details"""
    __tablename__ = "collaboration_invitations"
    
    id = Column(Integer, primary_key=True, index=True)
    project_id = Column(String, index=True, nullable=False)
    receiver_mobile = Column(String, nullable=False)
    inviter_id = Column(String, nullable=True)
    inviter_name = Column(String, nullable=True)
    role = Column(String, nullable=False)
    message = Column(Text, nullable=True)
    status = Column(String, default="pending")  # pending, accepted, declined, expired
    expires_at = Column(DateTime, nullable=True)
    responded_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class TeamActivity(Base):
    """Track team activity and collaboration events"""
    __tablename__ = "team_activities"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(String, index=True, nullable=False)
    user_id = Column(String, nullable=False)
    user_name = Column(String, nullable=False)
    activity_type = Column(String, nullable=False)  # work_added, checkpoint_completed, etc.
    activity_description = Column(Text, nullable=False)
    checkpoint_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
