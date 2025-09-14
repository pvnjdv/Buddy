from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, Enum, Float, JSON
from sqlalchemy.orm import relationship
from app.core.database import Base
from datetime import datetime
import enum

class FlowStatus(enum.Enum):
    active = "active"
    completed = "completed"
    paused = "paused"
    cancelled = "cancelled"

class FlowDifficulty(enum.Enum):
    easy = "easy"
    medium = "medium"
    hard = "hard"
    expert = "expert"

class CheckpointType(enum.Enum):
    task = "task"
    milestone = "milestone"
    review = "review"
    testing = "testing"

class ResourceType(enum.Enum):
    link = "link"
    document = "document"
    video = "video"
    tutorial = "tutorial"
    tool = "tool"

class MessageContext(enum.Enum):
    general = "general"
    flow_creation = "flow_creation"
    checkpoint_help = "checkpoint_help"
    flow_progress = "flow_progress"

class ProjectFlow(Base):
    __tablename__ = "project_flows"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String(255), nullable=False)
    description = Column(Text)
    status = Column(Enum(FlowStatus), default=FlowStatus.active)
    difficulty = Column(Enum(FlowDifficulty), default=FlowDifficulty.medium)
    estimated_duration = Column(String(100), default="1 week")
    current_checkpoint_index = Column(Integer, default=0)
    tags = Column(JSON, default=list)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    checkpoints = relationship("FlowCheckpoint", back_populates="flow", cascade="all, delete-orphan")
    buddy_messages = relationship("BuddyFlowMessage", back_populates="flow", cascade="all, delete-orphan")
    alarms = relationship("FlowAlarm", back_populates="flow", cascade="all, delete-orphan")

class FlowCheckpoint(Base):
    __tablename__ = "flow_checkpoints"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(Integer, ForeignKey("project_flows.id"))
    title = Column(String(255), nullable=False)
    description = Column(Text)
    order = Column(Integer, nullable=False)
    type = Column(Enum(CheckpointType), default=CheckpointType.task)
    estimated_time = Column(String(100), default="1 day")
    requirements = Column(JSON, default=list)
    deliverables = Column(JSON, default=list)
    buddy_help_prompt = Column(Text, nullable=True)  # AI guidance for this checkpoint
    is_completed = Column(Boolean, default=False)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    flow = relationship("ProjectFlow", back_populates="checkpoints")
    resources = relationship("FlowResource", back_populates="checkpoint", cascade="all, delete-orphan")
    # New relationships
    notes = relationship("FlowCheckpointNote", back_populates="checkpoint", cascade="all, delete-orphan")
    assignments = relationship("FlowCheckpointAssignment", back_populates="checkpoint", cascade="all, delete-orphan")

class FlowResource(Base):
    __tablename__ = "flow_resources"
    
    id = Column(Integer, primary_key=True, index=True)
    checkpoint_id = Column(Integer, ForeignKey("flow_checkpoints.id"))
    title = Column(String(255), nullable=False)
    description = Column(Text)
    url = Column(String(500))
    type = Column(Enum(ResourceType), default=ResourceType.link)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    checkpoint = relationship("FlowCheckpoint", back_populates="resources")

class BuddyFlowMessage(Base):
    __tablename__ = "buddy_flow_messages"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    flow_id = Column(Integer, ForeignKey("project_flows.id"), nullable=True)
    checkpoint_id = Column(Integer, ForeignKey("flow_checkpoints.id"), nullable=True)
    content = Column(Text, nullable=False)
    role = Column(String(20), nullable=False)  # 'user' or 'assistant'
    context = Column(Enum(MessageContext), default=MessageContext.general)
    timestamp = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    flow = relationship("ProjectFlow", back_populates="buddy_messages")

class ChatMessage(Base):
    __tablename__ = "chat_messages"
    
    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"))
    receiver_id = Column(Integer, ForeignKey("users.id"))
    content = Column(Text, nullable=False)
    message_type = Column(String(20), default="text")  # text, image, video, audio, document
    status = Column(String(20), default="sent")  # sent, delivered, read
    media_url = Column(String(500), nullable=True)
    reply_to_id = Column(Integer, ForeignKey("chat_messages.id"), nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])
    reply_to = relationship("ChatMessage", remote_side=[id])

class AlarmType(enum.Enum):
    reminder = "reminder"
    deadline = "deadline"
    meeting = "meeting"
    task = "task"
    custom = "custom"

class AlarmRepeat(enum.Enum):
    none = "none"
    daily = "daily"
    weekly = "weekly"
    monthly = "monthly"
    custom = "custom"

class FlowAlarm(Base):
    __tablename__ = "flow_alarms"
    
    id = Column(String(36), primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String(255), nullable=False)
    description = Column(Text)
    scheduled_time = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True)
    type = Column(Enum(AlarmType), default=AlarmType.reminder)
    repeat = Column(Enum(AlarmRepeat), default=AlarmRepeat.none)
    flow_id = Column(Integer, ForeignKey("project_flows.id"), nullable=True)
    checkpoint_id = Column(Integer, ForeignKey("flow_checkpoints.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_triggered = Column(DateTime, nullable=True)
    
    # Relationships
    user = relationship("User")
    flow = relationship("ProjectFlow", back_populates="alarms")

# New: Per-checkpoint notes
class FlowCheckpointNote(Base):
    __tablename__ = "flow_checkpoint_notes"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(Integer, ForeignKey("project_flows.id"), nullable=False)
    checkpoint_id = Column(Integer, ForeignKey("flow_checkpoints.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    tags = Column(JSON, default=list)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    checkpoint = relationship("FlowCheckpoint", back_populates="notes")

# New: Checkpoint assignment
class FlowCheckpointAssignment(Base):
    __tablename__ = "flow_checkpoint_assignments"
    
    id = Column(Integer, primary_key=True, index=True)
    flow_id = Column(Integer, ForeignKey("project_flows.id"), nullable=False)
    checkpoint_id = Column(Integer, ForeignKey("flow_checkpoints.id"), nullable=False)
    assignee_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    assignee_name = Column(String(255), nullable=True)
    assigned_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    assigned_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    checkpoint = relationship("FlowCheckpoint", back_populates="assignments")
