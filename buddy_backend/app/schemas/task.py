from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = None
    priority: Optional[str] = "normal"
    status: Optional[str] = "todo"
    due_date: Optional[datetime] = None
    labels: Optional[List[str]] = []
    flow_id: Optional[str] = None
    checkpoint_id: Optional[str] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    due_date: Optional[datetime] = None
    labels: Optional[List[str]] = None
    flow_id: Optional[str] = None
    checkpoint_id: Optional[str] = None

class TaskRead(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    status: str
    priority: str
    due_date: Optional[datetime] = None
    labels: List[str] = []
    flow_id: Optional[str] = None
    checkpoint_id: Optional[str] = None
    assigned_to: Optional[int] = None

    class Config:
        from_attributes = True