from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db, get_current_user
from app.schemas.task import TaskCreate, TaskRead
from app.crud.task import create_task, get_tasks, get_task, update_task_status, delete_task

router = APIRouter(prefix="/tasks", tags=["Tasks"])

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