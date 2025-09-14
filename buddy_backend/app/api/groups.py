# WhatsApp-like Group Chat Feature
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict
from datetime import datetime
import uuid
import os
from app.dependencies import get_db, get_current_user

router = APIRouter(prefix="/groups", tags=["Group Chats"])

# In-memory group storage (in production, use database)
groups = {}
group_memberships = {}

@router.post("/create")
async def create_group(
    name: str,
    description: str = "",
    participant_ids: List[int] = [],
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new group chat"""
    try:
        group_id = str(uuid.uuid4())
        
        # Add creator to participants
        all_participants = [current_user.id] + participant_ids
        
        group_data = {
            "id": group_id,
            "name": name,
            "description": description,
            "created_by": current_user.id,
            "created_at": datetime.now().isoformat(),
            "participants": all_participants,
            "admins": [current_user.id],
            "messages": [],
            "group_icon": None
        }
        
        groups[group_id] = group_data
        
        # Update memberships
        for participant_id in all_participants:
            if participant_id not in group_memberships:
                group_memberships[participant_id] = []
            group_memberships[participant_id].append(group_id)
        
        return {"message": "Group created successfully", "group_id": group_id, "group": group_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/my")
async def get_my_groups(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all groups current user is part of"""
    try:
        user_groups = []
        user_group_ids = group_memberships.get(current_user.id, [])
        
        for group_id in user_group_ids:
            if group_id in groups:
                group = groups[group_id]
                # Get last message info
                last_message = group["messages"][-1] if group["messages"] else None
                user_groups.append({
                    "id": group["id"],
                    "name": group["name"],
                    "description": group["description"],
                    "participant_count": len(group["participants"]),
                    "last_message": last_message,
                    "group_icon": group["group_icon"]
                })
        
        return {"groups": user_groups}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{group_id}")
async def get_group_details(
    group_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get group details"""
    try:
        if group_id not in groups:
            raise HTTPException(status_code=404, detail="Group not found")
        
        group = groups[group_id]
        
        # Check if user is member
        if current_user.id not in group["participants"]:
            raise HTTPException(status_code=403, detail="Not a group member")
        
        return {"group": group}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{group_id}/messages")
async def send_group_message(
    group_id: str,
    content: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Send message to group"""
    try:
        if group_id not in groups:
            raise HTTPException(status_code=404, detail="Group not found")
        
        group = groups[group_id]
        
        # Check if user is member
        if current_user.id not in group["participants"]:
            raise HTTPException(status_code=403, detail="Not a group member")
        
        message = {
            "id": str(uuid.uuid4()),
            "sender_id": current_user.id,
            "sender_name": current_user.name or current_user.mobile_number,
            "content": content,
            "timestamp": datetime.now().isoformat(),
            "type": "text"
        }
        
        group["messages"].append(message)
        
        return {"message": "Message sent", "data": message}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{group_id}/messages")
async def get_group_messages(
    group_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get group messages"""
    try:
        if group_id not in groups:
            raise HTTPException(status_code=404, detail="Group not found")
        
        group = groups[group_id]
        
        # Check if user is member
        if current_user.id not in group["participants"]:
            raise HTTPException(status_code=403, detail="Not a group member")
        
        return {"messages": group["messages"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{group_id}/participants")
async def add_participant(
    group_id: str,
    user_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Add participant to group (admin only)"""
    try:
        if group_id not in groups:
            raise HTTPException(status_code=404, detail="Group not found")
        
        group = groups[group_id]
        
        # Check if current user is admin
        if current_user.id not in group["admins"]:
            raise HTTPException(status_code=403, detail="Admin privileges required")
        
        # Add participant
        if user_id not in group["participants"]:
            group["participants"].append(user_id)
            
            # Update memberships
            if user_id not in group_memberships:
                group_memberships[user_id] = []
            group_memberships[user_id].append(group_id)
        
        return {"message": "Participant added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{group_id}/participants/{user_id}")
async def remove_participant(
    group_id: str,
    user_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Remove participant from group (admin only)"""
    try:
        if group_id not in groups:
            raise HTTPException(status_code=404, detail="Group not found")
        
        group = groups[group_id]
        
        # Check if current user is admin or removing themselves
        if current_user.id not in group["admins"] and current_user.id != user_id:
            raise HTTPException(status_code=403, detail="Admin privileges required")
        
        # Remove participant
        if user_id in group["participants"]:
            group["participants"].remove(user_id)
            
            # Update memberships
            if user_id in group_memberships and group_id in group_memberships[user_id]:
                group_memberships[user_id].remove(group_id)
        
        return {"message": "Participant removed successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{group_id}/icon")
async def upload_group_icon(
    group_id: str,
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Upload group icon (admin only)"""
    try:
        if group_id not in groups:
            raise HTTPException(status_code=404, detail="Group not found")
        
        group = groups[group_id]
        
        # Check if current user is admin
        if current_user.id not in group["admins"]:
            raise HTTPException(status_code=403, detail="Admin privileges required")
        
        # Create uploads directory
        upload_dir = "uploads/group_icons"
        os.makedirs(upload_dir, exist_ok=True)
        
        # Generate unique filename
        file_extension = os.path.splitext(file.filename)[1]
        unique_filename = f"{group_id}{file_extension}"
        file_path = os.path.join(upload_dir, unique_filename)
        
        # Save file
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Update group icon
        group["group_icon"] = f"/uploads/group_icons/{unique_filename}"
        
        return {"message": "Group icon updated successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{group_id}")
async def update_group_info(
    group_id: str,
    name: str = None,
    description: str = None,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update group name/description (admin only)"""
    try:
        if group_id not in groups:
            raise HTTPException(status_code=404, detail="Group not found")
        
        group = groups[group_id]
        
        # Check if current user is admin
        if current_user.id not in group["admins"]:
            raise HTTPException(status_code=403, detail="Admin privileges required")
        
        if name:
            group["name"] = name
        if description is not None:
            group["description"] = description
        
        return {"message": "Group updated successfully", "group": group}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
