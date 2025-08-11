from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db, get_current_user
from app.schemas.message import MessageCreate, MessageRead
from app.crud.message import create_message, get_messages, get_messages_between_users
from app.crud.user import get_all_users

router = APIRouter(prefix="/chats", tags=["Chats"])

@router.get("/contacts")
async def get_chat_contacts(
    db: AsyncSession = Depends(get_db)
    # Temporarily removed: current_user = Depends(get_current_user)
):
    """Get all users that can be contacted for chat"""
    try:
        users = await get_all_users(db)
        # Return all users with proper field mapping for ChatContact model
        contacts = []
        for user in users:
            # Use phone number as name if name is empty
            display_name = user.name if user.name and user.name.strip() else user.mobile_number
            contacts.append({
                "id": user.id,
                "name": display_name,
                "phone_number": user.mobile_number,
                "email": None,
                "profile_image_url": None,
                "last_message": None,
                "last_message_time": None,
                "unread_count": 0,
                "is_online": False
            })
        return contacts
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{chat_id}/messages")
async def get_chat_messages(
    chat_id: int,
    db: AsyncSession = Depends(get_db)
    # Temporarily removed: current_user = Depends(get_current_user)
):
    """Get messages for a specific chat/conversation with another user"""
    try:
        # For now, return empty list since we need current_user for proper filtering
        # In production, you'd need proper authentication
        return []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/send", response_model=MessageRead)
async def send_message(
    msg: MessageCreate,
    db: AsyncSession = Depends(get_db)
    # Temporarily removed: current_user = Depends(get_current_user)
):
    # For now, use a dummy sender_id since we don't have current_user
    # In production, you'd use current_user.id
    message = await create_message(db, 1, msg.receiver_id, msg.content)  # Using sender_id=1 as dummy
    return message

@router.get("/", response_model=list[MessageRead])
async def list_messages(
    db: AsyncSession = Depends(get_db)
    # Temporarily removed: current_user = Depends(get_current_user)
):
    # For now, return empty list since we need current_user for proper filtering
    return []