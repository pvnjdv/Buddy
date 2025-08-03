from sqlalchemy import Column, Integer, String
from app.core.database import Base
from sqlalchemy.orm import relationship

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    mobile_number = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=True)
    profile_photo = Column(String, nullable=True)  # Added for profile photo
    otp = Column(String, nullable=True)  # Store OTP temporarily
    tasks = relationship("Task", back_populates="owner")