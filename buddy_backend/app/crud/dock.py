# app/crud/dock.py
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta

from app.models.dock import Device, DeviceCommand, DeviceMacro, FileTransfer, DeviceGroup
from app.schemas.dock import (
    DeviceCreate, DeviceUpdate, CommandCreate, MacroCreate, MacroUpdate,
    FileTransferCreate, DeviceGroupCreate, DeviceGroupUpdate
)

class DeviceCRUD:
    @staticmethod
    def get_device(db: Session, device_id: str) -> Optional[Device]:
        return db.query(Device).filter(Device.id == device_id).first()
    
    @staticmethod
    def get_devices_by_owner(db: Session, owner_id: str, skip: int = 0, limit: int = 100) -> List[Device]:
        return db.query(Device).filter(Device.owner_id == owner_id).offset(skip).limit(limit).all()
    
    @staticmethod
    def get_device_by_ip(db: Session, ip_address: str, port: int) -> Optional[Device]:
        return db.query(Device).filter(
            and_(Device.ip_address == ip_address, Device.port == port)
        ).first()
    
    @staticmethod
    def create_device(db: Session, device: DeviceCreate, owner_id: str) -> Device:
        db_device = Device(
            **device.dict(),
            owner_id=owner_id
        )
        db.add(db_device)
        db.commit()
        db.refresh(db_device)
        return db_device
    
    @staticmethod
    def update_device(db: Session, device_id: str, device_update: DeviceUpdate) -> Optional[Device]:
        db_device = db.query(Device).filter(Device.id == device_id).first()
        if db_device:
            update_data = device_update.dict(exclude_unset=True)
            for field, value in update_data.items():
                setattr(db_device, field, value)
            db_device.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(db_device)
        return db_device
    
    @staticmethod
    def update_device_status(db: Session, device_id: str, status: str) -> Optional[Device]:
        db_device = db.query(Device).filter(Device.id == device_id).first()
        if db_device:
            db_device.status = status
            db_device.last_seen = datetime.utcnow()
            db.commit()
            db.refresh(db_device)
        return db_device
    
    @staticmethod
    def delete_device(db: Session, device_id: str) -> bool:
        db_device = db.query(Device).filter(Device.id == device_id).first()
        if db_device:
            db.delete(db_device)
            db.commit()
            return True
        return False
    
    @staticmethod
    def get_online_devices(db: Session, owner_id: str) -> List[Device]:
        return db.query(Device).filter(
            and_(Device.owner_id == owner_id, Device.status == "online")
        ).all()

class CommandCRUD:
    @staticmethod
    def get_command(db: Session, command_id: str) -> Optional[DeviceCommand]:
        return db.query(DeviceCommand).filter(DeviceCommand.id == command_id).first()
    
    @staticmethod
    def get_device_commands(db: Session, device_id: str, skip: int = 0, limit: int = 100) -> List[DeviceCommand]:
        return db.query(DeviceCommand).filter(DeviceCommand.device_id == device_id).offset(skip).limit(limit).all()
    
    @staticmethod
    def create_command(db: Session, command: CommandCreate) -> DeviceCommand:
        db_command = DeviceCommand(**command.dict())
        db.add(db_command)
        db.commit()
        db.refresh(db_command)
        return db_command
    
    @staticmethod
    def update_command_status(db: Session, command_id: str, status: str, result: str = None, error: str = None) -> Optional[DeviceCommand]:
        db_command = db.query(DeviceCommand).filter(DeviceCommand.id == command_id).first()
        if db_command:
            db_command.status = status
            if result is not None:
                db_command.result = result
            if error is not None:
                db_command.error_message = error
            if status == "running":
                db_command.executed_at = datetime.utcnow()
            elif status in ["completed", "failed"]:
                db_command.completed_at = datetime.utcnow()
            db.commit()
            db.refresh(db_command)
        return db_command
    
    @staticmethod
    def get_pending_commands(db: Session, device_id: str) -> List[DeviceCommand]:
        return db.query(DeviceCommand).filter(
            and_(DeviceCommand.device_id == device_id, DeviceCommand.status == "pending")
        ).all()

class MacroCRUD:
    @staticmethod
    def get_macro(db: Session, macro_id: str) -> Optional[DeviceMacro]:
        return db.query(DeviceMacro).filter(DeviceMacro.id == macro_id).first()
    
    @staticmethod
    def get_device_macros(db: Session, device_id: str, skip: int = 0, limit: int = 100) -> List[DeviceMacro]:
        return db.query(DeviceMacro).filter(DeviceMacro.device_id == device_id).offset(skip).limit(limit).all()
    
    @staticmethod
    def create_macro(db: Session, macro: MacroCreate) -> DeviceMacro:
        db_macro = DeviceMacro(**macro.dict())
        db.add(db_macro)
        db.commit()
        db.refresh(db_macro)
        return db_macro
    
    @staticmethod
    def update_macro(db: Session, macro_id: str, macro_update: MacroUpdate) -> Optional[DeviceMacro]:
        db_macro = db.query(DeviceMacro).filter(DeviceMacro.id == macro_id).first()
        if db_macro:
            update_data = macro_update.dict(exclude_unset=True)
            for field, value in update_data.items():
                setattr(db_macro, field, value)
            db_macro.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(db_macro)
        return db_macro
    
    @staticmethod
    def execute_macro(db: Session, macro_id: str) -> Optional[DeviceMacro]:
        db_macro = db.query(DeviceMacro).filter(DeviceMacro.id == macro_id).first()
        if db_macro:
            db_macro.execution_count += 1
            db_macro.last_executed = datetime.utcnow()
            db.commit()
            db.refresh(db_macro)
        return db_macro
    
    @staticmethod
    def delete_macro(db: Session, macro_id: str) -> bool:
        db_macro = db.query(DeviceMacro).filter(DeviceMacro.id == macro_id).first()
        if db_macro:
            db.delete(db_macro)
            db.commit()
            return True
        return False

class FileTransferCRUD:
    @staticmethod
    def get_transfer(db: Session, transfer_id: str) -> Optional[FileTransfer]:
        return db.query(FileTransfer).filter(FileTransfer.id == transfer_id).first()
    
    @staticmethod
    def get_device_transfers(db: Session, device_id: str, skip: int = 0, limit: int = 100) -> List[FileTransfer]:
        return db.query(FileTransfer).filter(FileTransfer.device_id == device_id).offset(skip).limit(limit).all()
    
    @staticmethod
    def create_transfer(db: Session, transfer: FileTransferCreate) -> FileTransfer:
        db_transfer = FileTransfer(**transfer.dict())
        db.add(db_transfer)
        db.commit()
        db.refresh(db_transfer)
        return db_transfer
    
    @staticmethod
    def update_transfer_progress(db: Session, transfer_id: str, progress: int, status: str = None) -> Optional[FileTransfer]:
        db_transfer = db.query(FileTransfer).filter(FileTransfer.id == transfer_id).first()
        if db_transfer:
            db_transfer.progress = progress
            if status:
                db_transfer.status = status
            if status == "transferring" and not db_transfer.started_at:
                db_transfer.started_at = datetime.utcnow()
            elif status in ["completed", "failed"]:
                db_transfer.completed_at = datetime.utcnow()
            db.commit()
            db.refresh(db_transfer)
        return db_transfer

class DeviceGroupCRUD:
    @staticmethod
    def get_group(db: Session, group_id: str) -> Optional[DeviceGroup]:
        return db.query(DeviceGroup).filter(DeviceGroup.id == group_id).first()
    
    @staticmethod
    def get_user_groups(db: Session, owner_id: str, skip: int = 0, limit: int = 100) -> List[DeviceGroup]:
        return db.query(DeviceGroup).filter(DeviceGroup.owner_id == owner_id).offset(skip).limit(limit).all()
    
    @staticmethod
    def create_group(db: Session, group: DeviceGroupCreate, owner_id: str) -> DeviceGroup:
        db_group = DeviceGroup(
            **group.dict(),
            owner_id=owner_id
        )
        db.add(db_group)
        db.commit()
        db.refresh(db_group)
        return db_group
    
    @staticmethod
    def update_group(db: Session, group_id: str, group_update: DeviceGroupUpdate) -> Optional[DeviceGroup]:
        db_group = db.query(DeviceGroup).filter(DeviceGroup.id == group_id).first()
        if db_group:
            update_data = group_update.dict(exclude_unset=True)
            for field, value in update_data.items():
                setattr(db_group, field, value)
            db_group.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(db_group)
        return db_group
    
    @staticmethod
    def delete_group(db: Session, group_id: str) -> bool:
        db_group = db.query(DeviceGroup).filter(DeviceGroup.id == group_id).first()
        if db_group:
            db.delete(db_group)
            db.commit()
            return True
        return False
