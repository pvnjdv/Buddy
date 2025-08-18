from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.core.database import get_db
from app.models.flow import FlowAlarm as FlowAlarmModel, AlarmType, AlarmRepeat
from app.models.user import User
from app.dependencies import get_current_user
import uuid

router = APIRouter(prefix="/alarms", tags=["alarms"]) 

class AlarmCreate(BaseModel):
    title: str
    description: Optional[str] = ""
    scheduled_time: datetime
    type: str = "reminder"  # reminder, deadline, meeting, task, custom
    repeat: str = "none"  # none, daily, weekly, monthly, custom
    flow_id: Optional[int] = None
    checkpoint_id: Optional[int] = None

class AlarmUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    scheduled_time: Optional[datetime] = None
    is_active: Optional[bool] = None
    type: Optional[str] = None
    repeat: Optional[str] = None

class AlarmResponse(BaseModel):
    id: str
    title: str
    description: str
    scheduled_time: datetime
    is_active: bool
    type: str
    repeat: str
    flow_id: Optional[int]
    checkpoint_id: Optional[int]
    created_at: datetime
    last_triggered: Optional[datetime]

    class Config:
        from_attributes = True

@router.get("/", response_model=List[AlarmResponse])
async def get_user_alarms(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all alarms for the current user"""
    try:
        result = await db.execute(
            select(FlowAlarmModel).where(FlowAlarmModel.user_id == current_user.id)
        )
        alarms = result.scalars().all()
        
        return [
            AlarmResponse(
                id=str(alarm.id),
                title=alarm.title,
                description=alarm.description or "",
                scheduled_time=alarm.scheduled_time,
                is_active=alarm.is_active,
                type=alarm.type.value if alarm.type else "reminder",
                repeat=alarm.repeat.value if alarm.repeat else "none",
                flow_id=alarm.flow_id,
                checkpoint_id=alarm.checkpoint_id,
                created_at=alarm.created_at,
                last_triggered=alarm.last_triggered
            )
            for alarm in alarms
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching alarms: {str(e)}")

@router.post("/", response_model=AlarmResponse)
async def create_alarm(
    alarm_data: AlarmCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new alarm"""
    try:
        # Validate enum values
        try:
            alarm_type = AlarmType(alarm_data.type)
        except ValueError:
            alarm_type = AlarmType.reminder
            
        try:
            repeat_type = AlarmRepeat(alarm_data.repeat)
        except ValueError:
            repeat_type = AlarmRepeat.none

        alarm = FlowAlarmModel(
            id=str(uuid.uuid4()),
            user_id=current_user.id,
            title=alarm_data.title,
            description=alarm_data.description,
            scheduled_time=alarm_data.scheduled_time,
            type=alarm_type,
            repeat=repeat_type,
            flow_id=alarm_data.flow_id,
            checkpoint_id=alarm_data.checkpoint_id,
            is_active=True,
            created_at=datetime.now()
        )
        
        db.add(alarm)
        await db.commit()
        await db.refresh(alarm)
        
        return AlarmResponse(
            id=str(alarm.id),
            title=alarm.title,
            description=alarm.description or "",
            scheduled_time=alarm.scheduled_time,
            is_active=alarm.is_active,
            type=alarm.type.value,
            repeat=alarm.repeat.value,
            flow_id=alarm.flow_id,
            checkpoint_id=alarm.checkpoint_id,
            created_at=alarm.created_at,
            last_triggered=alarm.last_triggered
        )
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating alarm: {str(e)}")

@router.get("/{alarm_id}", response_model=AlarmResponse)
async def get_alarm(
    alarm_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific alarm"""
    try:
        result = await db.execute(
            select(FlowAlarmModel).where(
                and_(
                    FlowAlarmModel.id == alarm_id,
                    FlowAlarmModel.user_id == current_user.id
                )
            )
        )
        alarm = result.scalar_one_or_none()
        
        if not alarm:
            raise HTTPException(status_code=404, detail="Alarm not found")
        
        return AlarmResponse(
            id=str(alarm.id),
            title=alarm.title,
            description=alarm.description or "",
            scheduled_time=alarm.scheduled_time,
            is_active=alarm.is_active,
            type=alarm.type.value,
            repeat=alarm.repeat.value,
            flow_id=alarm.flow_id,
            checkpoint_id=alarm.checkpoint_id,
            created_at=alarm.created_at,
            last_triggered=alarm.last_triggered
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching alarm: {str(e)}")

@router.put("/{alarm_id}", response_model=AlarmResponse)
async def update_alarm(
    alarm_id: str,
    alarm_data: AlarmUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update an existing alarm"""
    try:
        result = await db.execute(
            select(FlowAlarmModel).where(
                and_(
                    FlowAlarmModel.id == alarm_id,
                    FlowAlarmModel.user_id == current_user.id
                )
            )
        )
        alarm = result.scalar_one_or_none()
        
        if not alarm:
            raise HTTPException(status_code=404, detail="Alarm not found")
        
        # Update fields
        if alarm_data.title is not None:
            alarm.title = alarm_data.title
        if alarm_data.description is not None:
            alarm.description = alarm_data.description
        if alarm_data.scheduled_time is not None:
            alarm.scheduled_time = alarm_data.scheduled_time
        if alarm_data.is_active is not None:
            alarm.is_active = alarm_data.is_active
        if alarm_data.type is not None:
            try:
                alarm.type = AlarmType(alarm_data.type)
            except ValueError:
                pass  # Keep existing type if invalid
        if alarm_data.repeat is not None:
            try:
                alarm.repeat = AlarmRepeat(alarm_data.repeat)
            except ValueError:
                pass  # Keep existing repeat if invalid
        
        await db.commit()
        await db.refresh(alarm)
        
        return AlarmResponse(
            id=str(alarm.id),
            title=alarm.title,
            description=alarm.description or "",
            scheduled_time=alarm.scheduled_time,
            is_active=alarm.is_active,
            type=alarm.type.value,
            repeat=alarm.repeat.value,
            flow_id=alarm.flow_id,
            checkpoint_id=alarm.checkpoint_id,
            created_at=alarm.created_at,
            last_triggered=alarm.last_triggered
        )
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error updating alarm: {str(e)}")

@router.delete("/{alarm_id}")
async def delete_alarm(
    alarm_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete an alarm"""
    try:
        result = await db.execute(
            select(FlowAlarmModel).where(
                and_(
                    FlowAlarmModel.id == alarm_id,
                    FlowAlarmModel.user_id == current_user.id
                )
            )
        )
        alarm = result.scalar_one_or_none()
        
        if not alarm:
            raise HTTPException(status_code=404, detail="Alarm not found")
        
        await db.delete(alarm)
        await db.commit()
        
        return {"message": "Alarm deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error deleting alarm: {str(e)}")

@router.get("/active/upcoming", response_model=List[AlarmResponse])
async def get_upcoming_alarms(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get upcoming active alarms"""
    try:
        now = datetime.now()
        result = await db.execute(
            select(FlowAlarmModel).where(
                and_(
                    FlowAlarmModel.user_id == current_user.id,
                    FlowAlarmModel.is_active == True,
                    FlowAlarmModel.scheduled_time > now
                )
            ).order_by(FlowAlarmModel.scheduled_time)
        )
        alarms = result.scalars().all()
        
        return [
            AlarmResponse(
                id=str(alarm.id),
                title=alarm.title,
                description=alarm.description or "",
                scheduled_time=alarm.scheduled_time,
                is_active=alarm.is_active,
                type=alarm.type.value,
                repeat=alarm.repeat.value,
                flow_id=alarm.flow_id,
                checkpoint_id=alarm.checkpoint_id,
                created_at=alarm.created_at,
                last_triggered=alarm.last_triggered
            )
            for alarm in alarms
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching upcoming alarms: {str(e)}")

@router.post("/{alarm_id}/trigger")
async def trigger_alarm(
    alarm_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Mark an alarm as triggered"""
    try:
        result = await db.execute(
            select(FlowAlarmModel).where(
                and_(
                    FlowAlarmModel.id == alarm_id,
                    FlowAlarmModel.user_id == current_user.id
                )
            )
        )
        alarm = result.scalar_one_or_none()
        
        if not alarm:
            raise HTTPException(status_code=404, detail="Alarm not found")
        
        alarm.last_triggered = datetime.now()
        
        # Handle repeat logic
        if alarm.repeat == AlarmRepeat.none:
            alarm.is_active = False
        elif alarm.repeat == AlarmRepeat.daily:
            alarm.scheduled_time = alarm.scheduled_time.replace(
                day=alarm.scheduled_time.day + 1
            )
        elif alarm.repeat == AlarmRepeat.weekly:
            alarm.scheduled_time = alarm.scheduled_time.replace(
                day=alarm.scheduled_time.day + 7
            )
        elif alarm.repeat == AlarmRepeat.monthly:
            # Simple monthly repeat (same day next month)
            next_month = alarm.scheduled_time.month + 1
            next_year = alarm.scheduled_time.year
            if next_month > 12:
                next_month = 1
                next_year += 1
            alarm.scheduled_time = alarm.scheduled_time.replace(
                month=next_month,
                year=next_year
            )
        
        await db.commit()
        
        return {"message": "Alarm triggered successfully"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error triggering alarm: {str(e)}")
