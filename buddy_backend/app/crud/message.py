from sqlalchemy.future import select
from app.models.message import Message

async def create_message(db, sender_id, receiver_id, content):
    msg = Message(sender_id=sender_id, receiver_id=receiver_id, content=content)
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return msg

async def get_messages(db, user_id):
    result = await db.execute(
        select(Message).where((Message.sender_id == user_id) | (Message.receiver_id == user_id))
    )
    return result.scalars().all()

async def get_messages_between_users(db, user1_id, user2_id):
    """Get messages between two specific users"""
    result = await db.execute(
        select(Message).where(
            ((Message.sender_id == user1_id) & (Message.receiver_id == user2_id)) |
            ((Message.sender_id == user2_id) & (Message.receiver_id == user1_id))
        ).order_by(Message.timestamp)
    )
    return result.scalars().all()