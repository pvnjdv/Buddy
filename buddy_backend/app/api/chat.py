from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db, get_current_user
from app.schemas.message import MessageCreate, MessageRead
from app.crud.message import create_message, get_messages

router = APIRouter(prefix="/chats", tags=["Chats"])

@router.get("/contacts")
async def get_contacts(
    current_user = Depends(get_current_user)
):
    # Return sample contacts for now
    return [
        {
            "id": 1,
            "name": "John Doe",
            "mobile": "1234567890",
            "lastMessage": "Hey there!",
            "timestamp": "2025-08-08T10:30:00Z",
            "unreadCount": 2
        },
        {
            "id": 2,
            "name": "Jane Smith", 
            "mobile": "9876543210",
            "lastMessage": "How are you?",
            "timestamp": "2025-08-08T09:15:00Z",
            "unreadCount": 0
        }
    ]

@router.post("/send", response_model=MessageRead)
async def send_message(
    msg: MessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    message = await create_message(db, current_user.id, msg.receiver_id, msg.content)
    return message

@router.get("/", response_model=list[MessageRead])
async def list_messages(
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    messages = await get_messages(db, current_user.id)
    return messages