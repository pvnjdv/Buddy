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