from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db
from app.schemas.user import OTPRequest, OTPVerify
from app.crud.user import create_or_update_otp, verify_otp, update_user_refresh_token, get_user_by_mobile
from app.core.jwt import create_access_token, create_refresh_token, verify_token
from app.services.email_service import EmailService
from datetime import datetime, timedelta

import random

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/request-otp")
async def request_otp(payload: OTPRequest, db: AsyncSession = Depends(get_db)):
    # Test numbers with default OTP
    test_numbers = {
        "9270416640": "123456",
        "9579348057": "123456",
        "1234567890": "123456",
    }
    
    if payload.mobile_number in test_numbers:
        otp = test_numbers[payload.mobile_number]
        await create_or_update_otp(db, payload.mobile_number, otp)
        
        print(f"\n🔐 TEST OTP REQUEST")
        print(f"📱 Mobile: {payload.mobile_number}")
        print(f"🔢 OTP: {otp} (Test Account)")
        print("-" * 40)
        
        return {
            "mobile_number": payload.mobile_number, 
            "message": "Test OTP generated",
            "email_sent": False,
            "is_test_account": True
        }
    
    # Regular OTP generation for other numbers
    otp = str(random.randint(100000, 999999))
    await create_or_update_otp(db, payload.mobile_number, otp)
    
    # Try to send OTP via email to your fixed address
    email_sent = EmailService.send_otp_email(payload.mobile_number, otp)
    
    # Always show OTP in terminal for backup
    print(f"\n🔐 OTP REQUEST")
    print(f"📱 Mobile: {payload.mobile_number}")
    print(f"🔢 OTP: {otp}")
    print(f"📧 Email sent: {email_sent}")
    print(f"⏰ Time: {payload}")
    print("-" * 40)
    
    return {
        "mobile_number": payload.mobile_number, 
        "message": "OTP generated",
        "email_sent": email_sent,
        "is_test_account": False
    }

@router.post("/verify-otp")
async def verify_otp_endpoint(payload: OTPVerify, db: AsyncSession = Depends(get_db)):
    user = await verify_otp(db, payload.mobile_number, payload.otp)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid OTP")
    
    # Create both access and refresh tokens
    access_token = create_access_token({"sub": user.mobile_number})
    refresh_token = create_refresh_token({"sub": user.mobile_number})
    
    # Store refresh token in database
    refresh_expires = datetime.utcnow() + timedelta(days=30)
    await update_user_refresh_token(db, user.mobile_number, refresh_token, refresh_expires)
    
    return {
        "access_token": access_token, 
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": 30 * 60,  # 30 minutes for access token
        "refresh_expires_in": 30 * 24 * 60 * 60  # 30 days for refresh token
    }

@router.post("/refresh-token")
async def refresh_access_token(request: dict, db: AsyncSession = Depends(get_db)):
    refresh_token = request.get("refresh_token")
    if not refresh_token:
        raise HTTPException(status_code=400, detail="Refresh token required")
        
    # Verify refresh token
    payload = verify_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
    mobile_number = payload.get("sub")
    if not mobile_number:
        raise HTTPException(status_code=401, detail="Invalid token payload")
    
    # Check if refresh token exists in database and is valid
    user = await get_user_by_mobile(db, mobile_number)
    if not user or user.refresh_token != refresh_token:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
    if user.refresh_token_expires and user.refresh_token_expires < datetime.utcnow():
        raise HTTPException(status_code=401, detail="Refresh token expired")
    
    # Generate new access token
    new_access_token = create_access_token({"sub": mobile_number})
    
    return {
        "access_token": new_access_token,
        "token_type": "bearer",
        "expires_in": 30 * 60  # 30 minutes
    }

@router.post("/logout")
async def logout(request: dict, db: AsyncSession = Depends(get_db)):
    mobile_number = request.get("mobile_number")
    if not mobile_number:
        raise HTTPException(status_code=400, detail="Mobile number required")
        
    # Clear refresh token from database
    await update_user_refresh_token(db, mobile_number, None, None)
    return {"message": "Logged out successfully"}