# Enhanced collaboration Pydantic schemas

from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

# Work Contribution schemas
class WorkContributionCreate(BaseModel):
    flow_id: str
    checkpoint_id: str
    user_id: str
    user_name: str
    hours_worked: float
    work_description: str
    type: str

class WorkContributionResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    hours_worked: float
    work_description: str
    type: str
    contributed_at: datetime

    class Config:
        orm_mode = True

# AI Assistance schemas
class AIAssistanceCreate(BaseModel):
    flow_id: str
    checkpoint_id: str
    assistance_id: str
    query: str
    response: str
    type: str
    was_helpful: bool = False
    feedback: Optional[str] = None

class AIAssistanceResponse(BaseModel):
    assistance_id: str
    query: str
    response: str
    type: str
    was_helpful: bool
    feedback: Optional[str]
    requested_at: datetime

    class Config:
        orm_mode = True

# Checkpoint Assignment schemas
class CheckpointAssignmentCreate(BaseModel):
    flow_id: str
    checkpoint_id: str
    assignee_id: str
    assignee_name: str

class CheckpointAssignmentResponse(BaseModel):
    id: str
    flow_id: str
    checkpoint_id: str
    assignee_id: str
    assignee_name: str
    assigned_at: datetime

    class Config:
        orm_mode = True

# Checkpoint Comment schemas
class CheckpointCommentCreate(BaseModel):
    flow_id: str
    checkpoint_id: str
    user_id: str
    user_name: str
    comment: str

class CheckpointCommentResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    comment: str
    created_at: datetime

    class Config:
        orm_mode = True

# Team Statistics schema
class TeamStatsResponse(BaseModel):
    total_hours_worked: float
    total_contributors: int
    ai_assistance_sessions: int
    team_members: int
    last_activity: Optional[datetime]

# Enhanced Invitation schemas
class CollaborationInvitationCreate(BaseModel):
    project_id: str
    receiver_mobile: str
    inviter_id: Optional[str] = None
    inviter_name: Optional[str] = None
    role: str
    message: Optional[str] = None
    expires_at: Optional[datetime] = None

class CollaborationInvitationResponse(BaseModel):
    id: str
    project_id: str
    receiver_mobile: str
    inviter_name: Optional[str]
    role: str
    message: Optional[str]
    status: str
    expires_at: Optional[datetime]
    created_at: datetime

    class Config:
        orm_mode = True

# Team Activity schemas
class TeamActivityCreate(BaseModel):
    flow_id: str
    user_id: str
    user_name: str
    activity_type: str
    activity_description: str
    checkpoint_id: Optional[str] = None

class TeamActivityResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    activity_type: str
    activity_description: str
    checkpoint_id: Optional[str]
    created_at: datetime

    class Config:
        orm_mode = True

# Comprehensive collaboration overview
class CollaborationOverview(BaseModel):
    project_id: str
    project_title: str
    team_stats: TeamStatsResponse
    recent_activities: List[TeamActivityResponse]
    pending_invitations: List[CollaborationInvitationResponse]
    active_assignments: List[CheckpointAssignmentResponse]
