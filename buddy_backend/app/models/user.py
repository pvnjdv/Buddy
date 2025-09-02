from sqlalchemy import Column, Integer, String, DateTime
from app.core.database import Base
from sqlalchemy.orm import relationship
from datetime import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    mobile_number = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=True)
    profile_photo = Column(String, nullable=True)  # Added for profile photo
    otp = Column(String, nullable=True)  # Store OTP temporarily
    refresh_token = Column(String, nullable=True)  # Store refresh token
    refresh_token_expires = Column(DateTime, nullable=True)  # Refresh token expiry
    tasks = relationship("Task", back_populates="owner")
    ai_personas = relationship("AIPersona", back_populates="user")
    devices = relationship("Device", back_populates="owner")