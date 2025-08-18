from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.core.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.persona import AIPersona
from app.schemas.persona import (
    PersonaCreate, 
    PersonaUpdate, 
    PersonaResponse, 
    PersonaListResponse,
    PersonaActivateRequest
)
from app.crud.persona import persona_crud

router = APIRouter(prefix="/personas", tags=["AI Personas"])

@router.post("/", response_model=PersonaResponse, status_code=status.HTTP_201_CREATED)
async def create_persona(
    persona_data: PersonaCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new AI persona"""
    try:
        # Check if user already has a persona with the same name
        existing_personas = await persona_crud.get_user_personas(db, str(current_user.id))
        if any(p.name.lower() == persona_data.name.lower() for p in existing_personas):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You already have a persona named '{persona_data.name}'"
            )
        
        persona = await persona_crud.create_persona(db, persona_data, str(current_user.id))
        return PersonaResponse.from_orm(persona)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create persona: {str(e)}"
        )

@router.get("/", response_model=PersonaListResponse)
async def get_user_personas(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all personas for the current user"""
    try:
        personas = await persona_crud.get_user_personas(db, str(current_user.id))
        active_persona = await persona_crud.get_active_persona(db, str(current_user.id))
        
        return PersonaListResponse(
            personas=[PersonaResponse.from_orm(p) for p in personas],
            active_persona=PersonaResponse.from_orm(active_persona) if active_persona else None,
            total_count=len(personas)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch personas: {str(e)}"
        )

@router.get("/active", response_model=PersonaResponse)
async def get_active_persona(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get the currently active persona"""
    try:
        persona = await persona_crud.get_active_persona(db, str(current_user.id))
        if not persona:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No active persona found"
            )
        return PersonaResponse.from_orm(persona)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch active persona: {str(e)}"
        )

@router.put("/{persona_id}/activate")
async def activate_persona(
    persona_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Activate a specific persona"""
    try:
        success = await persona_crud.set_active_persona(db, persona_id, str(current_user.id))
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Persona not found"
            )
        return {"message": "Persona activated successfully", "persona_id": persona_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to activate persona: {str(e)}"
        )

@router.put("/deactivate")
async def deactivate_all_personas(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Deactivate all personas (clear active persona)"""
    try:
        await persona_crud.set_active_persona(db, None, str(current_user.id))
        return {"message": "All personas deactivated successfully"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to deactivate personas: {str(e)}"
        )

@router.put("/{persona_id}", response_model=PersonaResponse)
async def update_persona(
    persona_id: str,
    persona_data: PersonaUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update a persona"""
    try:
        persona = await persona_crud.update_persona(db, persona_id, persona_data, str(current_user.id))
        if not persona:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Persona not found"
            )
        return PersonaResponse.from_orm(persona)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update persona: {str(e)}"
        )

@router.delete("/{persona_id}")
async def delete_persona(
    persona_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a persona"""
    try:
        success = await persona_crud.delete_persona(db, persona_id, str(current_user.id))
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Persona not found or cannot be deleted (default personas cannot be deleted)"
            )
        return {"message": "Persona deleted successfully", "persona_id": persona_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete persona: {str(e)}"
        )

@router.get("/{persona_id}", response_model=PersonaResponse)
async def get_persona(
    persona_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific persona by ID"""
    try:
        persona = await persona_crud.get_persona_by_id(db, persona_id, str(current_user.id))
        if not persona:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Persona not found"
            )
        return PersonaResponse.from_orm(persona)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch persona: {str(e)}"
        )

@router.post("/initialize-defaults")
async def initialize_default_personas(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Initialize default personas for the user (Teacher, Developer, Writer)"""
    try:
        # Check if user already has personas
        existing_personas = await persona_crud.get_user_personas(db, str(current_user.id))
        if existing_personas:
            return {
                "message": "Default personas already exist or user has custom personas", 
                "persona_count": len(existing_personas)
            }
        
        await persona_crud.create_default_personas(db, str(current_user.id))
        return {"message": "Default personas created successfully"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create default personas: {str(e)}"
        )
