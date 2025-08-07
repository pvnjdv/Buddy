from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from enum import Enum

class FlowStatus(str, Enum):
    active = "active"
    completed = "completed"
    paused = "paused"
    cancelled = "cancelled"

class FlowDifficulty(str, Enum):
    easy = "easy"
    medium = "medium"
    hard = "hard"
    expert = "expert"

class CheckpointType(str, Enum):
    task = "task"
    milestone = "milestone"
    review = "review"
    testing = "testing"

class ResourceType(str, Enum):
    link = "link"
    document = "document"
    video = "video"
    tutorial = "tutorial"
    tool = "tool"

class MessageContext(str, Enum):
    general = "general"
    flow_creation = "flow_creation"
    checkpoint_help = "checkpoint_help"
    flow_progress = "flow_progress"

# Flow Resource schemas
class FlowResourceBase(BaseModel):
    title: str
    description: str
    url: str
    type: ResourceType = ResourceType.link

class FlowResourceCreate(FlowResourceBase):
    pass

class FlowResourceResponse(FlowResourceBase):
    id: int
    checkpoint_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# Flow Checkpoint schemas
class FlowCheckpointBase(BaseModel):
    title: str
    description: str
    order: int
    type: CheckpointType = CheckpointType.task
    estimated_time: str = "1 day"
    requirements: Optional[List[str]] = []
    deliverables: Optional[List[str]] = []

class FlowCheckpointCreate(FlowCheckpointBase):
    resources: Optional[List[FlowResourceCreate]] = []

class FlowCheckpointUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    type: Optional[CheckpointType] = None
    estimated_time: Optional[str] = None
    requirements: Optional[List[str]] = None
    deliverables: Optional[List[str]] = None
    is_completed: Optional[bool] = None

class FlowCheckpointResponse(FlowCheckpointBase):
    id: int
    flow_id: int
    is_completed: bool
    completed_at: Optional[datetime] = None
    created_at: datetime
    resources: List[FlowResourceResponse] = []
    
    class Config:
        from_attributes = True

# Project Flow schemas
class ProjectFlowBase(BaseModel):
    title: str
    description: str
    status: FlowStatus = FlowStatus.active
    difficulty: FlowDifficulty = FlowDifficulty.medium
    estimated_duration: str = "1 week"
    tags: Optional[List[str]] = []

class ProjectFlowCreate(ProjectFlowBase):
    checkpoints: List[FlowCheckpointCreate] = []

class ProjectFlowUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[FlowStatus] = None
    difficulty: Optional[FlowDifficulty] = None
    estimated_duration: Optional[str] = None
    current_checkpoint_index: Optional[int] = None
    tags: Optional[List[str]] = None

class ProjectFlowResponse(ProjectFlowBase):
    id: int
    user_id: int
    current_checkpoint_index: int = 0
    created_at: datetime
    updated_at: datetime
    checkpoints: List[FlowCheckpointResponse] = []
    
    class Config:
        from_attributes = True

# Buddy Flow Message schemas
class BuddyFlowMessageBase(BaseModel):
    content: str
    role: str  # 'user' or 'assistant'
    context: MessageContext = MessageContext.general

class BuddyFlowMessageCreate(BuddyFlowMessageBase):
    flow_id: Optional[int] = None
    checkpoint_id: Optional[int] = None

class BuddyFlowMessageResponse(BuddyFlowMessageBase):
    id: int
    user_id: int
    flow_id: Optional[int] = None
    checkpoint_id: Optional[int] = None
    timestamp: datetime
    
    class Config:
        from_attributes = True

# Flow Generation schemas
class FlowGenerationRequest(BaseModel):
    project_description: str
    preferences: Optional[dict] = {}

class FlowGenerationResponse(BaseModel):
    flow: ProjectFlowResponse
    message: str

# Chat Message schemas
class ChatMessageBase(BaseModel):
    content: str
    message_type: str = "text"
    media_url: Optional[str] = None
    reply_to_id: Optional[int] = None

class ChatMessageCreate(ChatMessageBase):
    receiver_id: int

class ChatMessageResponse(ChatMessageBase):
    id: int
    sender_id: int
    receiver_id: int
    status: str = "sent"
    timestamp: datetime
    
    class Config:
        from_attributes = True

class ChatContactResponse(BaseModel):
    id: int
    name: str
    phone_number: Optional[str] = None
    email: Optional[str] = None
    profile_image_url: Optional[str] = None
    last_message: Optional[str] = None
    last_message_time: Optional[datetime] = None
    unread_count: int = 0
    is_online: bool = False
    
    class Config:
        from_attributes = True
