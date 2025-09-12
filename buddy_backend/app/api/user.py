from fastapi import APIRouter, Depends, HTTPException, Query, Form, File, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
import base64
from app.dependencies import get_db, get_current_user
from app.schemas.user import UserDetails, UserRead
from app.crud.user import update_user_details, get_user_by_mobile as crud_get_user_by_mobile, get_user_by_id, get_all_users, search_users

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/me", response_model=UserRead)
async def get_current_user_profile(
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get current user's profile"""
    user = await get_user_by_id(db, current_user.id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.post("/details", response_model=UserRead)
async def add_details(
    details: UserDetails,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    try:
        print(f"Updating user details for user {current_user.id}: {details}")
        user = await update_user_details(
            db,
            current_user.id,
            details.name,
            details.profile_photo,
            details.profession
        )
        if not user:
            print(f"User {current_user.id} not found")
            raise HTTPException(status_code=404, detail="User not found")
        print(f"Successfully updated user: {user}")
        return user
    except Exception as e:
        print(f"Error updating user details: {e}")
        print(f"Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to update user details: {str(e)}")

@router.post("/profile", response_model=UserRead)
async def update_profile(
    name: str = Form(...),
    profession: str = Form(...),
    profile_photo: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Update user profile with file upload support"""
    try:
        print(f"Updating profile for user {current_user.id}")
        print(f"Name: {name}, Profession: {profession}")
        
        # Handle profile photo if provided
        profile_photo_base64 = None
        if profile_photo:
            print(f"Processing profile photo: {profile_photo.filename}")
            # Read the file content
            file_content = await profile_photo.read()
            # Convert to base64
            profile_photo_base64 = base64.b64encode(file_content).decode('utf-8')
            print(f"Converted photo to base64, length: {len(profile_photo_base64)}")
        
        user = await update_user_details(
            db,
            current_user.id,
            name,
            profile_photo_base64,
            profession
        )
        
        if not user:
            print(f"User {current_user.id} not found")
            raise HTTPException(status_code=404, detail="User not found")
        
        print(f"Successfully updated user profile: {user.name}")
        return user
        
    except Exception as e:
        print(f"Error updating user profile: {e}")
        print(f"Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to update profile: {str(e)}")

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