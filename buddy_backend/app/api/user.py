from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db, get_current_user
from app.schemas.user import UserDetails, UserRead
from app.crud.user import update_user_details, get_user_by_mobile as crud_get_user_by_mobile

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/details", response_model=UserRead)
async def add_details(
    details: UserDetails,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    user = await update_user_details(
        db,
        current_user.id,
        details.name,
        details.profile_photo
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.get("/by-mobile/{mobile}", response_model=UserRead)
async def get_user_by_mobile(
    mobile: str,
    db: AsyncSession = Depends(get_db)
):
    user = await crud_get_user_by_mobile(db, mobile)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user