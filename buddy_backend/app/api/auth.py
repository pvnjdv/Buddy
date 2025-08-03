from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db
from app.schemas.user import OTPRequest, OTPVerify
from app.crud.user import create_or_update_otp, verify_otp
from app.core.jwt import create_access_token

import random

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/request-otp")
async def request_otp(payload: OTPRequest, db: AsyncSession = Depends(get_db)):
    otp = str(random.randint(100000, 999999))
    await create_or_update_otp(db, payload.mobile_number, otp)
    # TODO: Integrate SMS API here. For now, return OTP for testing.
    return {"mobile_number": payload.mobile_number, "otp": otp}

@router.post("/verify-otp")
async def verify_otp_endpoint(payload: OTPVerify, db: AsyncSession = Depends(get_db)):
    user = await verify_otp(db, payload.mobile_number, payload.otp)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid OTP")
    token = create_access_token({"sub": user.mobile_number})
    return {"access_token": token, "token_type": "bearer"}