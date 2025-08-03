from pydantic import BaseModel

class TaskCreate(BaseModel):
    title: str
    description: str | None = None

class TaskRead(BaseModel):
    id: int
    title: str
    description: str | None = None
    status: str
    assigned_to: int | None = None

    class Config:
        from_attributes = True