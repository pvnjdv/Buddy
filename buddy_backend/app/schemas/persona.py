from pydantic import BaseModel, validator
from typing import Optional, List
from datetime import datetime

class PersonaBase(BaseModel):
    name: str
    description: Optional[str] = None
    system_prompt: Optional[str] = None
    personality_traits: Optional[str] = None
    expertise_areas: Optional[str] = None
    response_style: Optional[str] = "conversational"

class PersonaCreate(PersonaBase):
    @validator('name')
    def validate_name(cls, v):
        if not v or len(v.strip()) < 2:
            raise ValueError('Persona name must be at least 2 characters long')
        if len(v) > 100:
            raise ValueError('Persona name cannot exceed 100 characters')
        return v.strip()

class PersonaUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    system_prompt: Optional[str] = None
    personality_traits: Optional[str] = None
    expertise_areas: Optional[str] = None
    response_style: Optional[str] = None

class PersonaResponse(PersonaBase):
    id: str
    user_id: str
    is_active: bool
    is_default: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class PersonaListResponse(BaseModel):
    personas: List[PersonaResponse]
    active_persona: Optional[PersonaResponse] = None
    total_count: int

class PersonaActivateRequest(BaseModel):
    persona_id: str

class BuddyQueryWithPersona(BaseModel):
    prompt: str
    chat_history: Optional[List[dict]] = []
    persona_id: Optional[str] = None  # If provided, use this persona for the response
    is_flow_request: Optional[bool] = False
