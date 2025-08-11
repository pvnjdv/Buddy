from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.dependencies import get_db, get_current_user
from app.schemas.user import UserDetails, UserRead
from app.crud.user import update_user_details, get_user_by_mobile as crud_get_user_by_mobile, get_user_by_id, get_all_users, search_users

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

@router.get("/by-mobile/{mobile_number}", response_model=UserRead)
async def get_user_by_mobile_endpoint(
    mobile_number: str,
    db: AsyncSession = Depends(get_db)
):
    """Get user by mobile number"""
    # URL decode the mobile number
    import urllib.parse
    decoded_mobile = urllib.parse.unquote(mobile_number)
    
    user = await crud_get_user_by_mobile(db, decoded_mobile)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.get("/", response_model=List[UserRead])
async def get_all_users_endpoint(
    db: AsyncSession = Depends(get_db)
    # Temporarily removed: current_user = Depends(get_current_user)
):
    """Get all users for contact list"""
    users = await get_all_users(db)
    # Return all users for now (remove exclusion since no current_user)
    return users

@router.get("/search", response_model=List[UserRead])
async def search_users_endpoint(
    q: str = Query(..., description="Search query"),
    db: AsyncSession = Depends(get_db)
    # Temporarily removed: current_user = Depends(get_current_user)
):
    """Search users by name or mobile"""
    users = await search_users(db, q)
    # Return all users for now (remove exclusion since no current_user)
    return users

@router.get("/{user_id}", response_model=UserRead)
async def get_user_profile(
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get user profile by ID"""
    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user