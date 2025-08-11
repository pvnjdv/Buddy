from dotenv import load_dotenv
from pydantic_settings import BaseSettings
import os

load_dotenv()

class Settings(BaseSettings):
    APP_NAME: str = "Default App"
    SECRET_KEY: str = "insecure-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # AI Configuration
    AI_MODE: str = "local"  # "local" or "api" 
    MODEL_NAME: str = "mistral"
    MODEL_PATH: str = "/home/pvn/Desktop/Buddy/buddy_backend/app/models/llama/mistral-7b-instruct-v0.1.Q4_K_M.gguf"
    
    # Groq API Configuration
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.1-8b-instant"  # Updated to current supported model
    
    # Email Configuration
    SENDER_EMAIL: str = ""
    SENDER_APP_PASSWORD: str = ""
    TARGET_EMAIL: str = ""

    class Config:
        env_file = ".env"

settings = Settings()