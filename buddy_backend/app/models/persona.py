from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Boolean
from app.core.database import Base
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

class AIPersona(Base):
    """AI Persona model for custom AI personalities"""
    __tablename__ = "ai_personas"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    system_prompt = Column(Text, nullable=True)  # Custom system prompt for this persona
    personality_traits = Column(Text, nullable=True)  # JSON string of traits
    expertise_areas = Column(Text, nullable=True)  # JSON string of expertise areas
    response_style = Column(String(50), nullable=True)  # e.g., "formal", "casual", "technical"
    is_active = Column(Boolean, default=False)  # Is this the currently active persona for the user
    is_default = Column(Boolean, default=False)  # Is this a system default persona
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship with user
    user = relationship("User", back_populates="ai_personas")
    
    def to_dict(self):
        """Convert persona to dictionary for API responses"""
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "system_prompt": self.system_prompt,
            "personality_traits": self.personality_traits,
            "expertise_areas": self.expertise_areas,
            "response_style": self.response_style,
            "is_active": self.is_active,
            "is_default": self.is_default,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }
