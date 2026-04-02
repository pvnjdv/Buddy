# Enhanced WhatsApp-like chat endpoints with comprehensive features
# trial Comment 
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import and_, or_, desc, func
from jose import JWTError, jwt
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import json
import os
import uuid
from app.dependencies import get_db, get_current_user
from app.core.config import settings
from app.schemas.message import MessageCreate, MessageRead
from app.crud.message import create_message, get_messages_between_users, get_last_message_between_users, delete_messages_between_users
from app.crud.user import get_all_users, get_user_by_mobile

router = APIRouter(prefix="/chats", tags=["Chats"]) 

# Simple in-memory WebSocket connection manager per user
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, user_id: int, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.setdefault(user_id, []).append(websocket)

    def disconnect(self, user_id: int, websocket: WebSocket):
        conns = self.active_connections.get(user_id, [])
        if websocket in conns:
            conns.remove(websocket)
        if not conns and user_id in self.active_connections:
            del self.active_connections[user_id]

    async def send_to_user(self, user_id: int, data: dict):
        if user_id in self.active_connections:
            for ws in list(self.active_connections[user_id]):
                try:
                    await ws.send_json(data)
                except Exception:
                    # Drop broken connection
                    self.disconnect(user_id, ws)

manager = ConnectionManager()

async def _get_user_from_token(token: str, db: AsyncSession) -> int:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        mobile_number: str | None = payload.get("sub")
        if not mobile_number:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        user = await get_user_by_mobile(db, mobile_number)
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user.id
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Token error: {e}")

@router.get("/contacts")
async def get_chat_contacts(
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user),
):
    """Get chat contacts with last message preview (only users with history), ordered by latest first"""
    try:
        users = await get_all_users(db)
        contacts = []
        for user in users:
            if user.id == current_user.id:
                continue
            display_name = user.name.strip() if user.name and user.name.strip() else user.mobile_number
            last_msg = await get_last_message_between_users(db, current_user.id, user.id)
            if not last_msg:
                continue  # Only include users with existing chat history
            contacts.append({
                "id": user.id,
                "name": display_name,
                "phone_number": user.mobile_number,
                "email": None,
                "profile_image_url": getattr(user, 'profile_photo', None),
                "last_message": last_msg.content,
                "last_message_time": last_msg.timestamp.isoformat(),
                "unread_count": 0,
                "is_online": False,
            })
        # Sort by newest message first
        contacts.sort(key=lambda c: c.get("last_message_time") or "", reverse=True)
        return contacts
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{other_user_id}/messages", response_model=list[MessageRead])
async def get_chat_messages(
    other_user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user),
):
    """Get messages between current user and the specified other user"""
    try:
        messages = await get_messages_between_users(db, current_user.id, other_user_id)
        return messages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/send", response_model=MessageRead)
async def send_message(
    msg: MessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user),
):
    """Send a message using Authorization header for sender"""
    try:
        message = await create_message(db, current_user.id, msg.receiver_id, msg.content)
        payload = {
            "id": message.id,
            "sender_id": message.sender_id,
            "receiver_id": message.receiver_id,
            "content": message.content,
            "timestamp": message.timestamp.isoformat(),
        }
        await manager.send_to_user(msg.receiver_id, {"type": "message", "data": payload})
        await manager.send_to_user(current_user.id, {"type": "ack", "data": payload})
        return message
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.websocket("/ws")
async def chat_ws(websocket: WebSocket, token: str = Query(...), db: AsyncSession = Depends(get_db)):
    """WebSocket endpoint for real-time chat. Pass JWT in query param 'token'.
    Messages must be JSON: {"receiver_id": int, "content": str}
    """
    # Validate token and get user id
    user_id = await _get_user_from_token(token, db)
    await manager.connect(user_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            receiver_id = int(data.get("receiver_id"))
            content = (data.get("content") or "").strip()
            if not receiver_id or not content:
                await websocket.send_json({"type": "error", "detail": "receiver_id and content required"})
                continue
            # Persist message
            message = await create_message(db, user_id, receiver_id, content)
            payload = {
                "id": message.id,
                "sender_id": message.sender_id,
                "receiver_id": message.receiver_id,
                "content": message.content,
                "timestamp": message.timestamp.isoformat(),
            }
            # Send to receiver and echo back to sender
            await manager.send_to_user(receiver_id, {"type": "message", "data": payload})
            await manager.send_to_user(user_id, {"type": "ack", "data": payload})
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception:
        manager.disconnect(user_id, websocket)
        try:
            await websocket.close()
        except Exception:
            pass

@router.delete("/{other_user_id}/clear")
async def clear_chat(
    other_user_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Clear all messages between current user and another user"""
    try:
        await delete_messages_between_users(db, current_user.id, other_user_id)
        return {"message": "Chat cleared successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to clear chat")

# Enhanced WhatsApp-like Features

@router.post("/{message_id}/read")
async def mark_message_as_read(
    message_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Mark a message as read (blue ticks)"""
    try:
        # In a real implementation, you'd update message status in database
        await manager.send_to_user(current_user.id, {
            "type": "read_receipt", 
            "data": {"message_id": message_id, "read_by": current_user.id}
        })
        return {"message": "Message marked as read"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{other_user_id}/typing")
async def send_typing_indicator(
    other_user_id: int,
    typing: bool,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Send typing indicator to another user"""
    try:
        await manager.send_to_user(other_user_id, {
            "type": "typing",
            "data": {"user_id": current_user.id, "typing": typing}
        })
        return {"message": "Typing status sent"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{other_user_id}/online-status")
async def update_online_status(
    other_user_id: int,
    is_online: bool,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update and broadcast online status"""
    try:
        # Broadcast online status to all contacts
        await manager.send_to_user(other_user_id, {
            "type": "online_status",
            "data": {"user_id": current_user.id, "is_online": is_online, "last_seen": datetime.now().isoformat()}
        })
        return {"message": "Online status updated"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/media/upload")
async def upload_media(
    file: UploadFile = File(...),
    receiver_id: int = Query(...),
    message_type: str = Query(default="image"),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Upload media file (image, video, document, audio)"""
    try:
        # Create uploads directory if it doesn't exist
        upload_dir = "uploads/media"
        os.makedirs(upload_dir, exist_ok=True)
        
        # Generate unique filename
        file_extension = os.path.splitext(file.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(upload_dir, unique_filename)
        
        # Save file
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Create message with media
        message = await create_message(
            db, 
            current_user.id, 
            receiver_id, 
            f"{message_type.title()} file"
        )
        
        # Broadcast message with media URL
        payload = {
            "id": message.id,
            "sender_id": message.sender_id,
            "receiver_id": message.receiver_id,
            "content": message.content,
            "timestamp": message.timestamp.isoformat(),
            "media_url": f"/uploads/media/{unique_filename}",
            "media_type": message_type
        }
        
        await manager.send_to_user(receiver_id, {"type": "message", "data": payload})
        await manager.send_to_user(current_user.id, {"type": "ack", "data": payload})
        
        return {"message": "Media uploaded successfully", "media_url": f"/uploads/media/{unique_filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{other_user_id}/media")
async def get_shared_media(
    other_user_id: int,
    media_type: Optional[str] = Query(None),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all shared media between two users"""
    try:
        # In a real implementation, you'd filter messages by media type from database
        messages = await get_messages_between_users(db, current_user.id, other_user_id)
        
        # Filter media messages (this would be done at database level in production)
        media_messages = []
        for msg in messages:
            # Mock media filtering - in real implementation, check message.media_url
            if "image" in msg.content.lower() or "video" in msg.content.lower() or "document" in msg.content.lower():
                media_messages.append({
                    "id": msg.id,
                    "content": msg.content,
                    "timestamp": msg.timestamp.isoformat(),
                    "media_type": "image",  # This would come from database
                    "media_url": f"/uploads/media/sample_{msg.id}.jpg"  # Mock URL
                })
        
        return {"media": media_messages}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{other_user_id}/block")
async def block_user(
    other_user_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Block a user"""
    try:
        # In production, you'd create a blocked_users table
        # For now, just return success
        return {"message": f"User {other_user_id} blocked successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{other_user_id}/block")
async def unblock_user(
    other_user_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Unblock a user"""
    try:
        # In production, you'd remove from blocked_users table
        return {"message": f"User {other_user_id} unblocked successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{other_user_id}/search")
async def search_messages(
    other_user_id: int,
    query: str = Query(...),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Search messages in a chat"""
    try:
        messages = await get_messages_between_users(db, current_user.id, other_user_id)
        
        # Simple text search (in production, use full-text search)
        matching_messages = []
        for msg in messages:
            if query.lower() in msg.content.lower():
                matching_messages.append({
                    "id": msg.id,
                    "content": msg.content,
                    "timestamp": msg.timestamp.isoformat(),
                    "sender_id": msg.sender_id
                })
        
        return {"results": matching_messages}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{message_id}/star")
async def star_message(
    message_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Star/favorite a message"""
    try:
        # In production, you'd have a starred_messages table
        return {"message": "Message starred successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{message_id}/star")
async def unstar_message(
    message_id: int,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Remove star from message"""
    try:
        return {"message": "Message unstarred successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/starred")
async def get_starred_messages(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all starred messages for current user"""
    try:
        # In production, query starred_messages table
        return {"starred_messages": []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))