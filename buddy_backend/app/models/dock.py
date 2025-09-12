# app/models/dock.py
from sqlalchemy import Column, String, Text, DateTime, Boolean, Integer, JSON, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base
from app.models.user import User
import uuid

class Device(Base):
    __tablename__ = "devices"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    platform = Column(String, nullable=False)  # windows, macos, linux, android, ios
    ip_address = Column(String, nullable=False)
    port = Column(Integer, default=8000)
    status = Column(String, default="offline")  # online, offline, busy
    last_seen = Column(DateTime(timezone=True), server_default=func.now())
    capabilities = Column(JSON, default=lambda: {})  # What the device can do
    device_metadata = Column(JSON, default=lambda: {})  # Additional device info
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    owner = relationship("User", back_populates="devices")
    commands = relationship("DeviceCommand", back_populates="device")
    macros = relationship("DeviceMacro", back_populates="device")

class DeviceCommand(Base):
    __tablename__ = "device_commands"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    device_id = Column(String, ForeignKey("devices.id"), nullable=False)
    command_type = Column(String, nullable=False)  # system, app, file, etc.
    command = Column(Text, nullable=False)
    parameters = Column(JSON, default=lambda: {})
    status = Column(String, default="pending")  # pending, running, completed, failed
    result = Column(Text)
    error_message = Column(Text)
    executed_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    device = relationship("Device", back_populates="commands")

class DeviceMacro(Base):
    __tablename__ = "device_macros"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    description = Column(Text)
    device_id = Column(String, ForeignKey("devices.id"), nullable=False)
    commands = Column(JSON, nullable=False)  # List of commands to execute
    is_active = Column(Boolean, default=True)
    execution_count = Column(Integer, default=0)
    last_executed = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    device = relationship("Device", back_populates="macros")

class FileTransfer(Base):
    __tablename__ = "file_transfers"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    device_id = Column(String, ForeignKey("devices.id"), nullable=False)
    source_path = Column(Text, nullable=False)
    destination_path = Column(Text, nullable=False)
    file_size = Column(Integer)
    transfer_type = Column(String, nullable=False)  # upload, download
    status = Column(String, default="pending")  # pending, transferring, completed, failed
    progress = Column(Integer, default=0)  # Percentage
    error_message = Column(Text)
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    device = relationship("Device")

class DeviceGroup(Base):
    __tablename__ = "device_groups"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    description = Column(Text)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False)
    device_ids = Column(JSON, default=lambda: [])  # List of device IDs
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    owner = relationship("User")

# Update User model to include devices relationship
# This should be added to the User model in user.py, but for reference:
# devices = relationship("Device", back_populates="owner")
