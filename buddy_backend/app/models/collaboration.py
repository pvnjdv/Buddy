# app/models/collaboration.py
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, Enum, JSON
from sqlalchemy.orm import relationship
from app.core.database import Base
from datetime import datetime
import enum
import uuid

class CollaborationStatus(enum.Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    active = "active"
    completed = "completed"
    cancelled = "cancelled"

class CollaborationRole(enum.Enum):
    owner = "owner"
    admin = "admin"
    contributor = "contributor"
    viewer = "viewer"

class ProjectCollaboration(Base):
    __tablename__ = "project_collaborations"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(Integer, ForeignKey("project_flows.id"))
    owner_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String(255), nullable=False)
    description = Column(Text)
    status = Column(Enum(CollaborationStatus), default=CollaborationStatus.active)
    settings = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    project = relationship("ProjectFlow")
    owner = relationship("User", foreign_keys=[owner_id])
    collaborators = relationship("CollaborationMember", back_populates="collaboration", cascade="all, delete-orphan")
    invitations = relationship("CollaborationInvitation", back_populates="collaboration", cascade="all, delete-orphan")
    ai_insights = relationship("AICollaborationInsight", back_populates="collaboration", cascade="all, delete-orphan")

class CollaborationMember(Base):
    __tablename__ = "collaboration_members"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    collaboration_id = Column(String(36), ForeignKey("project_collaborations.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    role = Column(Enum(CollaborationRole), default=CollaborationRole.contributor)
    permissions = Column(JSON, default={})
    joined_at = Column(DateTime, default=datetime.utcnow)
    last_active = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    collaboration = relationship("ProjectCollaboration", back_populates="collaborators")
    user = relationship("User")

class CollaborationInvitation(Base):
    __tablename__ = "collaboration_invitations"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    collaboration_id = Column(String(36), ForeignKey("project_collaborations.id"))
    inviter_id = Column(Integer, ForeignKey("users.id"))
    invitee_mobile = Column(String(20), nullable=False)  # Mobile number for invitation
    invitee_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Set when user joins
    role = Column(Enum(CollaborationRole), default=CollaborationRole.contributor)
    status = Column(Enum(CollaborationStatus), default=CollaborationStatus.pending)
    message = Column(Text)
    invited_at = Column(DateTime, default=datetime.utcnow)
    responded_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=True)
    
    # Relationships
    collaboration = relationship("ProjectCollaboration", back_populates="invitations")
    inviter = relationship("User", foreign_keys=[inviter_id])
    invitee = relationship("User", foreign_keys=[invitee_id])

class AICollaborationInsight(Base):
    __tablename__ = "ai_collaboration_insights"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    collaboration_id = Column(String(36), ForeignKey("project_collaborations.id"))
    insight_type = Column(String(50), nullable=False)  # progress, suggestion, blocker, milestone
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    insight_metadata = Column(JSON, default={})
    relevance_score = Column(Integer, default=0)  # 0-100
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    collaboration = relationship("ProjectCollaboration", back_populates="ai_insights")

class CollaborationActivity(Base):
    __tablename__ = "collaboration_activities"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    collaboration_id = Column(String(36), ForeignKey("project_collaborations.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    activity_type = Column(String(50), nullable=False)  # checkpoint_complete, file_edit, comment, etc.
    description = Column(Text, nullable=False)
    activity_metadata = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User")
