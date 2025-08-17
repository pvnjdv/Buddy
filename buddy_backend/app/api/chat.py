from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.ext.asyncio import AsyncSession
from jose import JWTError, jwt
from typing import Dict, List
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