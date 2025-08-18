from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, func, JSON, Boolean
from sqlalchemy.orm import relationship
from app.core.database import Base

class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    # Status values: todo | inProgress | done | blocked
    status = Column(String(50), default="todo", nullable=False)
    # Priority values: low | normal | high | urgent
    priority = Column(String(20), default="normal", nullable=False)
    due_date = Column(DateTime, nullable=True)
    labels = Column(JSON, default=list)
    flow_id = Column(String(64), nullable=True)
    checkpoint_id = Column(String(64), nullable=True)

    assigned_to = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    owner = relationship("User", back_populates="tasks")
