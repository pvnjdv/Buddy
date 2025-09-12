from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_
from app.models.user import User
from typing import List
from datetime import datetime

async def get_user_by_mobile(db: AsyncSession, mobile_number: str):
    result = await db.execute(select(User).where(User.mobile_number == mobile_number))
    return result.scalar_one_or_none()

async def get_user_by_id(db: AsyncSession, user_id: int):
    """Get user by ID"""
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()

async def create_or_update_otp(db: AsyncSession, mobile_number: str, otp: str):
    user = await get_user_by_mobile(db, mobile_number)
    if user:
        user.otp = otp
    else:
        user = User(mobile_number=mobile_number, otp=otp)
        db.add(user)
    await db.commit()
    await db.refresh(user)
    return user

async def verify_otp(db: AsyncSession, mobile_number: str, otp: str):
    user = await get_user_by_mobile(db, mobile_number)
    if user and user.otp == otp:
        user.otp = None  # Clear OTP after verification
        await db.commit()
        await db.refresh(user)
        return user
    return None

async def update_user_refresh_token(db: AsyncSession, mobile_number: str, refresh_token: str | None, expires: datetime | None):
    """Update user's refresh token and expiry"""
    user = await get_user_by_mobile(db, mobile_number)
    if user:
        user.refresh_token = refresh_token
        user.refresh_token_expires = expires
        await db.commit()
        await db.refresh(user)
    return user

async def update_user_details(db: AsyncSession, user_id: int, name: str, profile_photo: str | None = None, profession: str | None = None):
    try:
        print(f"CRUD: Updating user {user_id} with name='{name}', profile_photo='{profile_photo}', profession='{profession}'")
        user = await db.get(User, user_id)
        if user:
            print(f"CRUD: Found user {user_id}: {user.mobile_number}")
            user.name = name
            user.profile_photo = profile_photo
            user.profession = profession
            print(f"CRUD: Updated user fields, committing...")
            await db.commit()
            print(f"CRUD: Committed, refreshing...")
            await db.refresh(user)
            print(f"CRUD: Successfully updated user: {user.name}, {user.profession}")
        else:
            print(f"CRUD: User {user_id} not found")
        return user
    except Exception as e:
        print(f"CRUD Error: {e}")
        print(f"CRUD Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        await db.rollback()
        raise e

async def get_all_users(db: AsyncSession) -> List[User]:
    """Get all users for contact list (include users even if name is null)"""
    result = await db.execute(select(User))
    return result.scalars().all()

async def search_users(db: AsyncSession, query: str) -> List[User]:
    """Search users by name or mobile number"""
    result = await db.execute(
        select(User).where(
            or_(
                User.name.ilike(f"%{query}%"),
                User.mobile_number.ilike(f"%{query}%")
            )
        )
    )
    return result.scalars().all()