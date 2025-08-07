from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from app.dependencies import get_db, get_current_user
import json
from datetime import datetime

router = APIRouter(prefix="/notes", tags=["Notes"])

class NoteCreate(BaseModel):
    title: str
    content: str
    labels: List[str] = []
    color: str = "#FFFFFF"
    is_pinned: bool = False
    note_type: str = "text"
    checklist: List[Dict[str, Any]] = []

class NoteUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    labels: Optional[List[str]] = None
    color: Optional[str] = None
    is_pinned: Optional[bool] = None
    is_archived: Optional[bool] = None
    note_type: Optional[str] = None
    checklist: Optional[List[Dict[str, Any]]] = None

class NoteRead(BaseModel):
    id: str
    title: str
    content: str
    labels: List[str]
    color: str
    is_pinned: bool
    is_archived: bool
    created_at: datetime
    updated_at: datetime
    note_type: str
    checklist: List[Dict[str, Any]]

# Mock data store (in production, use proper database)
notes_store = {}

@router.post("/", response_model=NoteRead)
async def create_note(
    note: NoteCreate,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    note_id = str(len(notes_store) + 1)
    now = datetime.now()
    
    new_note = {
        "id": note_id,
        "title": note.title,
        "content": note.content,
        "labels": note.labels,
        "color": note.color,
        "is_pinned": note.is_pinned,
        "is_archived": False,
        "created_at": now,
        "updated_at": now,
        "note_type": note.note_type,
        "checklist": note.checklist,
        "user_id": current_user.id
    }
    
    notes_store[note_id] = new_note
    return NoteRead(**new_note)

@router.get("/", response_model=List[NoteRead])
async def get_notes(
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    user_notes = [
        note for note in notes_store.values() 
        if note.get("user_id") == current_user.id and not note.get("is_archived", False)
    ]
    return [NoteRead(**note) for note in user_notes]

@router.put("/{note_id}", response_model=NoteRead)
async def update_note(
    note_id: str,
    note_update: NoteUpdate,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    if note_id not in notes_store:
        raise HTTPException(status_code=404, detail="Note not found")
    
    existing_note = notes_store[note_id]
    if existing_note.get("user_id") != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    # Update fields
    for field, value in note_update.model_dump(exclude_unset=True).items():
        if value is not None:
            existing_note[field] = value
    
    existing_note["updated_at"] = datetime.now()
    notes_store[note_id] = existing_note
    
    return NoteRead(**existing_note)

@router.delete("/{note_id}")
async def delete_note(
    note_id: str,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    if note_id not in notes_store:
        raise HTTPException(status_code=404, detail="Note not found")
    
    existing_note = notes_store[note_id]
    if existing_note.get("user_id") != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    del notes_store[note_id]
    return {"message": "Note deleted successfully"}

@router.get("/search", response_model=List[NoteRead])
async def search_notes(
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    user_notes = [
        note for note in notes_store.values() 
        if (note.get("user_id") == current_user.id and 
            not note.get("is_archived", False) and
            (q.lower() in note.get("title", "").lower() or 
             q.lower() in note.get("content", "").lower()))
    ]
    return [NoteRead(**note) for note in user_notes]

@router.get("/labels", response_model=List[str])
async def get_labels(
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    all_labels = set()
    for note in notes_store.values():
        if note.get("user_id") == current_user.id:
            all_labels.update(note.get("labels", []))
    return list(all_labels)
