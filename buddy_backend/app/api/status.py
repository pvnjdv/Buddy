# WhatsApp-like Status/Stories Feature
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
from datetime import datetime, timedelta
import os
import uuid
from app.dependencies import get_db, get_current_user
from app.crud.user import get_all_users

router = APIRouter(prefix="/status", tags=["Status"])

# In-memory status storage (in production, use database)
user_statuses = {}

@router.post("/upload")
async def upload_status(
    file: UploadFile = File(...),
    caption: Optional[str] = None,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Upload a status (image/video with 24h expiry)"""
    try:
        # Create uploads directory
        upload_dir = "uploads/status"
        os.makedirs(upload_dir, exist_ok=True)
        
        # Generate unique filename
        file_extension = os.path.splitext(file.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(upload_dir, unique_filename)
        
        # Save file
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Store status info
        status_id = str(uuid.uuid4())
        status_data = {
            "id": status_id,
            "user_id": current_user.id,
            "user_name": current_user.name or current_user.mobile_number,
            "media_url": f"/uploads/status/{unique_filename}",
            "caption": caption,
            "timestamp": datetime.now().isoformat(),
            "expires_at": (datetime.now() + timedelta(hours=24)).isoformat(),
            "views": [],
            "media_type": "image" if file.content_type.startswith("image") else "video"
        }
        
        if current_user.id not in user_statuses:
            user_statuses[current_user.id] = []
        user_statuses[current_user.id].append(status_data)
        
        return {"message": "Status uploaded successfully", "status_id": status_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/all")
async def get_all_statuses(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all active statuses from contacts"""
    try:
        all_statuses = []
        current_time = datetime.now()
        
        for user_id, statuses in user_statuses.items():
            if user_id == current_user.id:
                continue
                
            # Filter non-expired statuses
            active_statuses = []
            for status in statuses:
                expires_at = datetime.fromisoformat(status["expires_at"])
                if expires_at > current_time:
                    active_statuses.append(status)
            
            if active_statuses:
                all_statuses.extend(active_statuses)
        
        return {"statuses": all_statuses}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/my")
async def get_my_statuses(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get current user's statuses"""
    try:
        user_status_list = user_statuses.get(current_user.id, [])
        current_time = datetime.now()
        
        # Filter non-expired statuses
        active_statuses = []
        for status in user_status_list:
            expires_at = datetime.fromisoformat(status["expires_at"])
            if expires_at > current_time:
                active_statuses.append(status)
        
        return {"statuses": active_statuses}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{status_id}/view")
async def view_status(
    status_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Mark status as viewed"""
    try:
        # Find status and add viewer
        for user_id, statuses in user_statuses.items():
            for status in statuses:
                if status["id"] == status_id:
                    if current_user.id not in status["views"]:
                        status["views"].append({
                            "user_id": current_user.id,
                            "user_name": current_user.name or current_user.mobile_number,
                            "viewed_at": datetime.now().isoformat()
                        })
                    return {"message": "Status viewed"}
        
        raise HTTPException(status_code=404, detail="Status not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{status_id}/views")
async def get_status_views(
    status_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get list of users who viewed the status"""
    try:
        # Find status
        for user_id, statuses in user_statuses.items():
            if user_id != current_user.id:
                continue
            for status in statuses:
                if status["id"] == status_id:
                    return {"views": status["views"]}
        
        raise HTTPException(status_code=404, detail="Status not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{status_id}")
async def delete_status(
    status_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a status"""
    try:
        user_status_list = user_statuses.get(current_user.id, [])
        user_statuses[current_user.id] = [s for s in user_status_list if s["id"] != status_id]
        return {"message": "Status deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
