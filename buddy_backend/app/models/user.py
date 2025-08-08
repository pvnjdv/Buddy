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
    
    # Relationships
    tasks = relationship("Task", back_populates="owner")
    flows = relationship("ProjectFlow", back_populates="user")
    sent_messages = relationship("Message", foreign_keys="Message.sender_id", back_populates="sender")
    received_messages = relationship("Message", foreign_keys="Message.receiver_id", back_populates="receiver")