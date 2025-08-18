from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from datetime import datetime
from app.models.task import Task

async def create_task(
    db: AsyncSession,
    title: str,
    description: Optional[str] = None,
    assigned_to: Optional[int] = None,
    priority: str = "normal",
    status: str = "todo",
    due_date: Optional[datetime] = None,
    labels: Optional[list] = None,
    flow_id: Optional[str] = None,
    checkpoint_id: Optional[str] = None,
):
    task = Task(
        title=title,
        description=description,
        assigned_to=assigned_to,
        priority=priority,
        status=status,
        due_date=due_date,
        labels=labels or [],
        flow_id=flow_id,
        checkpoint_id=checkpoint_id,
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task

async def get_tasks(db: AsyncSession, assigned_to: Optional[int] = None) -> List[Task]:
    if assigned_to is not None:
        result = await db.execute(select(Task).where(Task.assigned_to == assigned_to))
    else:
        result = await db.execute(select(Task))
    return result.scalars().all()

async def get_task(db: AsyncSession, task_id: int) -> Optional[Task]:
    return await db.get(Task, task_id)

async def update_task(db: AsyncSession, task_id: int, **fields) -> Optional[Task]:
    task = await db.get(Task, task_id)
    if not task:
        return None
    for k, v in fields.items():
        if v is not None and hasattr(task, k):
            setattr(task, k, v)
    await db.commit()
    await db.refresh(task)
    return task

async def update_task_status(db: AsyncSession, task_id: int, status: str) -> Optional[Task]:
    return await update_task(db, task_id, status=status)

async def delete_task(db: AsyncSession, task_id: int) -> Optional[Task]:
    task = await db.get(Task, task_id)
    if task:
        await db.delete(task)
        await db.commit()
    return task

async def search_tasks(db: AsyncSession, q: str, assigned_to: Optional[int] = None) -> List[Task]:
    like = f"%{q.lower()}%"
    if assigned_to is not None:
        result = await db.execute(
            select(Task).where(
                (Task.assigned_to == assigned_to)
                & ((Task.title.ilike(like)) | (Task.description.ilike(like)))
            )
        )
    else:
        result = await db.execute(
            select(Task).where((Task.title.ilike(like)) | (Task.description.ilike(like)))
        )
    return result.scalars().all()