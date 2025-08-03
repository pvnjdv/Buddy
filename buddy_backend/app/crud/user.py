from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.user import User

async def get_user_by_mobile(db: AsyncSession, mobile_number: str):
    result = await db.execute(select(User).where(User.mobile_number == mobile_number))
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

async def update_user_details(db: AsyncSession, user_id: int, name: str, profile_photo: str | None = None):
    user = await db.get(User, user_id)
    if user:
        user.name = name
        user.profile_photo = profile_photo
        await db.commit()
        await db.refresh(user)
    return user