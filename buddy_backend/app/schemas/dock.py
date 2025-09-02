# app/schemas/dock.py
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime

# Device schemas
class DeviceBase(BaseModel):
    name: str
    platform: str
    ip_address: str
    port: Optional[int] = 8000
    capabilities: Optional[Dict[str, Any]] = {}
    device_metadata: Optional[Dict[str, Any]] = {}

class DeviceCreate(DeviceBase):
    pass

class DeviceUpdate(BaseModel):
    name: Optional[str] = None
    status: Optional[str] = None
    capabilities: Optional[Dict[str, Any]] = None
    device_metadata: Optional[Dict[str, Any]] = None

class DeviceResponse(DeviceBase):
    id: str
    status: str
    last_seen: datetime
    owner_id: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

# Command schemas
class CommandBase(BaseModel):
    command_type: str
    command: str
    parameters: Optional[Dict[str, Any]] = {}

class CommandCreate(CommandBase):
    device_id: str

class CommandResponse(CommandBase):
    id: str
    device_id: str
    status: str
    result: Optional[str] = None
    error_message: Optional[str] = None
    executed_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

# Macro schemas
class MacroBase(BaseModel):
    name: str
    description: Optional[str] = None
    commands: List[Dict[str, Any]]

class MacroCreate(MacroBase):
    device_id: str

class MacroUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    commands: Optional[List[Dict[str, Any]]] = None
    is_active: Optional[bool] = None

class MacroResponse(MacroBase):
    id: str
    device_id: str
    is_active: bool
    execution_count: int
    last_executed: Optional[datetime] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

# File transfer schemas
class FileTransferBase(BaseModel):
    source_path: str
    destination_path: str
    transfer_type: str  # upload, download

class FileTransferCreate(FileTransferBase):
    device_id: str
    file_size: Optional[int] = None

class FileTransferResponse(FileTransferBase):
    id: str
    device_id: str
    file_size: Optional[int] = None
    status: str
    progress: int
    error_message: Optional[str] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

# Device group schemas
class DeviceGroupBase(BaseModel):
    name: str
    description: Optional[str] = None
    device_ids: List[str] = []

class DeviceGroupCreate(DeviceGroupBase):
    pass

class DeviceGroupUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    device_ids: Optional[List[str]] = None

class DeviceGroupResponse(DeviceGroupBase):
    id: str
    owner_id: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

# WebSocket message schemas
class WebSocketMessage(BaseModel):
    type: str
    data: Dict[str, Any]
    device_id: Optional[str] = None

class DeviceStatusUpdate(BaseModel):
    device_id: str
    status: str
    metadata: Optional[Dict[str, Any]] = None

class CommandExecution(BaseModel):
    command_id: str
    device_id: str
    command: str
    status: str
    result: Optional[str] = None
    error: Optional[str] = None

# System control schemas
class SystemAction(BaseModel):
    action: str  # shutdown, restart, sleep, wake, lock
    delay: Optional[int] = 0  # Delay in seconds
    force: Optional[bool] = False

class ProcessAction(BaseModel):
    action: str  # start, stop, kill, list
    process_name: Optional[str] = None
    process_id: Optional[int] = None
    parameters: Optional[List[str]] = []

class NetworkScan(BaseModel):
    ip_range: str = "192.168.1.0/24"
    ports: List[int] = [22, 80, 443, 8000]
    timeout: int = 5
