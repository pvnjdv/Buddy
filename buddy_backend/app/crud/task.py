from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.task import Task

async def create_task(db: AsyncSession, title: str, description: str, assigned_to: int | None = None):
    task = Task(title=title, description=description, assigned_to=assigned_to)
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task

async def get_tasks(db: AsyncSession):
    result = await db.execute(select(Task))
    return result.scalars().all()

async def get_task(db: AsyncSession, task_id: int):
    return await db.get(Task, task_id)

async def update_task_status(db: AsyncSession, task_id: int, status: str):
    task = await db.get(Task, task_id)
    if task:
        task.status = status
        await db.commit()
        await db.refresh(task)
    return task

async def delete_task(db: AsyncSession, task_id: int):
    task = await db.get(Task, task_id)
    if task:
        await db.delete(task)
        await db.commit()
    return task