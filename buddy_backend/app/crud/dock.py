# app/crud/dock.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import and_, or_, select, delete, update
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta

from app.models.dock import Device, DeviceCommand, DeviceMacro, FileTransfer, DeviceGroup
from app.schemas.dock import (
    DeviceCreate, DeviceUpdate, CommandCreate, MacroCreate, MacroUpdate,
    FileTransferCreate, DeviceGroupCreate, DeviceGroupUpdate
)

class DeviceCRUD:
    @staticmethod
    async def get_device(db: AsyncSession, device_id: str) -> Optional[Device]:
        result = await db.execute(select(Device).filter(Device.id == device_id))
        return result.scalars().first()
    
    @staticmethod
    async def get_devices_by_owner(db: AsyncSession, owner_id: str, skip: int = 0, limit: int = 100) -> List[Device]:
        result = await db.execute(
            select(Device).filter(Device.owner_id == owner_id).offset(skip).limit(limit)
        )
        return result.scalars().all()
    
    @staticmethod
    async def get_device_by_ip(db: AsyncSession, ip_address: str, port: int) -> Optional[Device]:
        result = await db.execute(
            select(Device).filter(
                and_(Device.ip_address == ip_address, Device.port == port)
            )
        )
        return result.scalars().first()
    
    @staticmethod
    async def create_device(db: AsyncSession, device: DeviceCreate, owner_id: str) -> Device:
        db_device = Device(
            **device.model_dump(),
            owner_id=owner_id,
            last_seen=datetime.utcnow(),
            status="online"
        )
        db.add(db_device)
        await db.commit()
        await db.refresh(db_device)
        return db_device
    
    @staticmethod
    async def update_device(db: AsyncSession, device_id: str, device_update: DeviceUpdate) -> Optional[Device]:
        result = await db.execute(select(Device).filter(Device.id == device_id))
        db_device = result.scalars().first()
        if db_device:
            update_data = device_update.model_dump(exclude_unset=True)
            for key, value in update_data.items():
                setattr(db_device, key, value)
            
            db_device.last_seen = datetime.utcnow()
            await db.commit()
            await db.refresh(db_device)
        return db_device
    
    @staticmethod
    async def update_device_status(db: AsyncSession, device_id: str, status: str) -> Optional[Device]:
        result = await db.execute(select(Device).filter(Device.id == device_id))
        db_device = result.scalars().first()
        if db_device:
            db_device.status = status
            db_device.last_seen = datetime.utcnow()
            await db.commit()
            await db.refresh(db_device)
        return db_device
    
    @staticmethod
    async def delete_device(db: AsyncSession, device_id: str) -> bool:
        result = await db.execute(select(Device).filter(Device.id == device_id))
        db_device = result.scalars().first()
        if db_device:
            await db.delete(db_device)
            await db.commit()
            return True
        return False
    
    @staticmethod
    async def get_online_devices(db: AsyncSession, owner_id: str) -> List[Device]:
        result = await db.execute(
            select(Device).filter(and_(Device.owner_id == owner_id, Device.status == "online"))
        )
        return result.scalars().all()

class CommandCRUD:
    @staticmethod
    async def get_command(db: AsyncSession, command_id: str) -> Optional[DeviceCommand]:
        result = await db.execute(select(DeviceCommand).filter(DeviceCommand.id == command_id))
        return result.scalars().first()
    
    @staticmethod
    async def get_device_commands(db: AsyncSession, device_id: str, skip: int = 0, limit: int = 100) -> List[DeviceCommand]:
        result = await db.execute(
            select(DeviceCommand).filter(DeviceCommand.device_id == device_id).offset(skip).limit(limit)
        )
        return result.scalars().all()
    
    @staticmethod
    async def create_command(db: AsyncSession, command: CommandCreate) -> DeviceCommand:
        db_command = DeviceCommand(**command.model_dump())
        db.add(db_command)
        await db.commit()
        await db.refresh(db_command)
        return db_command
    
    @staticmethod
    async def update_command_status(db: AsyncSession, command_id: str, status: str, result: str = None, error: str = None) -> Optional[DeviceCommand]:
        db_command = await CommandCRUD.get_command(db, command_id)
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
            await db.commit()
            await db.refresh(db_command)
        return db_command
    
    @staticmethod
    async def get_pending_commands(db: AsyncSession, device_id: str) -> List[DeviceCommand]:
        result = await db.execute(
            select(DeviceCommand).filter(and_(DeviceCommand.device_id == device_id, DeviceCommand.status == "pending"))
        )
        return result.scalars().all()

class MacroCRUD:
    @staticmethod
    async def get_macro(db: AsyncSession, macro_id: str) -> Optional[DeviceMacro]:
        result = await db.execute(select(DeviceMacro).filter(DeviceMacro.id == macro_id))
        return result.scalars().first()
    
    @staticmethod
    async def get_device_macros(db: AsyncSession, device_id: str, skip: int = 0, limit: int = 100) -> List[DeviceMacro]:
        result = await db.execute(
            select(DeviceMacro).filter(DeviceMacro.device_id == device_id).offset(skip).limit(limit)
        )
        return result.scalars().all()
    
    @staticmethod
    async def create_macro(db: AsyncSession, macro: MacroCreate) -> DeviceMacro:
        db_macro = DeviceMacro(**macro.model_dump())
        db.add(db_macro)
        await db.commit()
        await db.refresh(db_macro)
        return db_macro
    
    @staticmethod
    async def update_macro(db: AsyncSession, macro_id: str, macro_update: MacroUpdate) -> Optional[DeviceMacro]:
        db_macro = await MacroCRUD.get_macro(db, macro_id)
        if db_macro:
            update_data = macro_update.model_dump(exclude_unset=True)
            for field, value in update_data.items():
                setattr(db_macro, field, value)
            db_macro.updated_at = datetime.utcnow()
            await db.commit()
            await db.refresh(db_macro)
        return db_macro
    
    @staticmethod
    async def execute_macro(db: AsyncSession, macro_id: str) -> Optional[DeviceMacro]:
        db_macro = await MacroCRUD.get_macro(db, macro_id)
        if db_macro:
            db_macro.execution_count += 1
            db_macro.last_executed = datetime.utcnow()
            await db.commit()
            await db.refresh(db_macro)
        return db_macro
    
    @staticmethod
    async def delete_macro(db: AsyncSession, macro_id: str) -> bool:
        db_macro = await MacroCRUD.get_macro(db, macro_id)
        if db_macro:
            await db.delete(db_macro)
            await db.commit()
            return True
        return False

class FileTransferCRUD:
    @staticmethod
    async def get_transfer(db: AsyncSession, transfer_id: str) -> Optional[FileTransfer]:
        result = await db.execute(select(FileTransfer).filter(FileTransfer.id == transfer_id))
        return result.scalars().first()
    
    @staticmethod
    async def get_device_transfers(db: AsyncSession, device_id: str, skip: int = 0, limit: int = 100) -> List[FileTransfer]:
        result = await db.execute(
            select(FileTransfer).filter(FileTransfer.device_id == device_id).offset(skip).limit(limit)
        )
        return result.scalars().all()
    
    @staticmethod
    async def create_transfer(db: AsyncSession, transfer: FileTransferCreate) -> FileTransfer:
        db_transfer = FileTransfer(**transfer.model_dump())
        db.add(db_transfer)
        await db.commit()
        await db.refresh(db_transfer)
        return db_transfer
    
    @staticmethod
    async def update_transfer_progress(db: AsyncSession, transfer_id: str, progress: int, status: str = None) -> Optional[FileTransfer]:
        db_transfer = await FileTransferCRUD.get_transfer(db, transfer_id)
        if db_transfer:
            db_transfer.progress = progress
            if status:
                db_transfer.status = status
            if status == "transferring" and not db_transfer.started_at:
                db_transfer.started_at = datetime.utcnow()
            elif status in ["completed", "failed"]:
                db_transfer.completed_at = datetime.utcnow()
            await db.commit()
            await db.refresh(db_transfer)
        return db_transfer

class DeviceGroupCRUD:
    @staticmethod
    async def get_group(db: AsyncSession, group_id: str) -> Optional[DeviceGroup]:
        result = await db.execute(select(DeviceGroup).filter(DeviceGroup.id == group_id))
        return result.scalars().first()
    
    @staticmethod
    async def get_user_groups(db: AsyncSession, owner_id: str, skip: int = 0, limit: int = 100) -> List[DeviceGroup]:
        result = await db.execute(
            select(DeviceGroup).filter(DeviceGroup.owner_id == owner_id).offset(skip).limit(limit)
        )
        return result.scalars().all()
    
    @staticmethod
    async def create_group(db: AsyncSession, group: DeviceGroupCreate, owner_id: str) -> DeviceGroup:
        db_group = DeviceGroup(
            **group.model_dump(),
            owner_id=owner_id
        )
        db.add(db_group)
        await db.commit()
        await db.refresh(db_group)
        return db_group
    
    @staticmethod
    async def update_group(db: AsyncSession, group_id: str, group_update: DeviceGroupUpdate) -> Optional[DeviceGroup]:
        db_group = await DeviceGroupCRUD.get_group(db, group_id)
        if db_group:
            update_data = group_update.model_dump(exclude_unset=True)
            for field, value in update_data.items():
                setattr(db_group, field, value)
            db_group.updated_at = datetime.utcnow()
            await db.commit()
            await db.refresh(db_group)
        return db_group
    
    @staticmethod
    async def delete_group(db: AsyncSession, group_id: str) -> bool:
        db_group = await DeviceGroupCRUD.get_group(db, group_id)
        if db_group:
            await db.delete(db_group)
            await db.commit()
            return True
        return False
