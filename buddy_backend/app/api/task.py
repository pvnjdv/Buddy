from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Dict, Any, List
from app.dependencies import get_db, get_current_user
from app.schemas.task import TaskCreate, TaskRead
from app.crud.task import create_task, get_tasks, get_task, update_task_status, delete_task
import json

router = APIRouter(prefix="/tasks", tags=["Tasks"])

class TimelineTaskCreate(BaseModel):
    user_id: str
    timeline_data: Dict[str, Any]

@router.post("/create-from-timeline", response_model=TaskRead)
async def create_task_from_timeline(
    request: TimelineTaskCreate,
    db: AsyncSession = Depends(get_db)
):
    """Create a task with checkpoints from AI-generated timeline"""
    try:
        timeline_data = request.timeline_data
        tasks = timeline_data.get('tasks', [])
        
        if not tasks:
            raise HTTPException(status_code=400, detail="No tasks found in timeline")
        
        # Create main project task
        project_title = f"Project: {tasks[0].get('title', 'AI Generated Project')}"
        project_description = f"""
AI Generated Project Timeline

Estimated Duration: {timeline_data.get('estimated_duration', 'Unknown')}
Difficulty: {timeline_data.get('difficulty', 'Medium')}

Checkpoints:
""" + "\n".join([f"• {task.get('title', 'Task')}: {task.get('description', '')}" 
                 for task in tasks])

        # Store timeline data as JSON in description for now
        project_description += f"\n\nTimeline Data: {json.dumps(timeline_data)}"
        
        new_task = await create_task(
            db, 
            title=project_title,
            description=project_description,
            assigned_to=int(request.user_id)
        )
        
        return new_task
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create task from timeline: {str(e)}")

@router.post("/", response_model=TaskRead)
async def create_task_endpoint(
    task: TaskCreate,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    new_task = await create_task(db, task.title, task.description, assigned_to=current_user.id)
    return new_task

@router.get("/", response_model=list[TaskRead])
async def list_tasks(
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return await get_tasks(db)

@router.get("/{task_id}", response_model=TaskRead)
async def get_task_endpoint(
    task_id: int,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    task = await get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task

@router.patch("/{task_id}/status", response_model=TaskRead)
async def update_task_status_endpoint(
    task_id: int,
    status: str,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    task = await update_task_status(db, task_id, status)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task

@router.delete("/{task_id}", response_model=dict)
async def delete_task_endpoint(
    task_id: int,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    await delete_task(db, task_id)
    return {"detail": "Task deleted"}