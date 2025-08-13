from pydantic import BaseModel

class OTPRequest(BaseModel):
    mobile_number: str

class OTPVerify(BaseModel):
    mobile_number: str
    otp: str

class UserDetails(BaseModel):
    name: str
    profile_photo: str | None = None

class UserRead(BaseModel):
    id: int
    mobile_number: str
    name: str | None = None
    profile_photo: str | None = None

    class Config:
        from_attributes = True