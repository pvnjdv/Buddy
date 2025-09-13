from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum


class CollaborationStatus(str, Enum):
    active = "active"
    paused = "paused"
    completed = "completed"
    cancelled = "cancelled"


class CollaborationRole(str, Enum):
    owner = "owner"
    admin = "admin"
    contributor = "contributor"
    viewer = "viewer"


class CollaborationCreate(BaseModel):
    project_id: int
    name: str
    description: Optional[str] = None
    settings: Optional[Dict[str, Any]] = None


class CollaborationInvitationCreate(BaseModel):
    collaboration_id: str
    invitee_mobile: str
    role: CollaborationRole
    message: Optional[str] = None
    expires_at: Optional[datetime] = None


class CollaborationInvitationResponse(BaseModel):
    invitation_id: str
    response: str  # "accepted" or "rejected"


class CollaborationMemberSchema(BaseModel):
    id: str
    user_id: int
    user_name: str
    role: CollaborationRole
    joined_at: datetime
    last_active: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class CollaborationInvitationSchema(BaseModel):
    id: str
    collaboration_name: str
    inviter_name: str
    role: CollaborationRole
    message: Optional[str] = None
    invited_at: datetime
    expires_at: Optional[datetime] = None
    status: str
    responded_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class CollaborationProjectSchema(BaseModel):
    id: str
    project_id: int
    name: str
    description: Optional[str] = None
    status: CollaborationStatus
    member_count: int
    created_at: datetime
    updated_at: datetime
    members: List[CollaborationMemberSchema] = []

    model_config = ConfigDict(from_attributes=True)


class AICollaborationInsightSchema(BaseModel):
    id: str
    collaboration_id: str
    insight_type: str
    title: str
    content: str
    insight_metadata: Dict[str, Any] = {}
    relevance_score: int = 0
    is_read: bool = False
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CollaborationActivitySchema(BaseModel):
    id: str
    collaboration_id: str
    user_id: int
    activity_type: str
    description: str
    activity_metadata: Dict[str, Any] = {}
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AIInsightRequest(BaseModel):
    collaboration_id: str
    analysis_type: str = "general"  # general, progress, blockers, suggestions


class CollaborationAnalysisSchema(BaseModel):
    total_commits: int = 0
    active_members: int = 0
    completion_rate: float = 0.0
    recent_activity: int = 0
    productivity_score: float = 0.0
    collaboration_health: str = "good"
    insights: List[AICollaborationInsightSchema] = []
