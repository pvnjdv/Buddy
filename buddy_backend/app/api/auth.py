from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db
from app.schemas.user import OTPRequest, OTPVerify
from app.crud.user import create_or_update_otp, verify_otp
from app.core.jwt import create_access_token
from app.services.email_service import EmailService

import random

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/request-otp")
async def request_otp(payload: OTPRequest, db: AsyncSession = Depends(get_db)):
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
        "email_sent": email_sent
    }

@router.post("/verify-otp")
async def verify_otp_endpoint(payload: OTPVerify, db: AsyncSession = Depends(get_db)):
    user = await verify_otp(db, payload.mobile_number, payload.otp)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid OTP")
    token = create_access_token({"sub": user.mobile_number})
    return {"access_token": token, "token_type": "bearer"}