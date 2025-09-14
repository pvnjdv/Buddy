from dotenv import load_dotenv
from pydantic_settings import BaseSettings
import os

# Load .env file first
load_dotenv()

class Settings(BaseSettings):
    # App Configuration
    APP_NAME: str = os.getenv("APP_NAME", "Default App")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "insecure-key")
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30  # 1 month refresh token validity
    
    # Groq API Configuration
    GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")
    GROQ_MODEL: str = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
    
    # Email Configuration
    SENDER_EMAIL: str = os.getenv("SENDER_EMAIL", "")
    SENDER_APP_PASSWORD: str = os.getenv("SENDER_APP_PASSWORD", "")
    TARGET_EMAIL: str = os.getenv("TARGET_EMAIL", "")

    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'
        case_sensitive = False

# Create settings instance
settings = Settings()

# Debug: Print current settings (remove in production)
if __name__ == "__main__":
    print(f"AI_MODE: {settings.AI_MODE}")
    print(f"APP_NAME: {settings.APP_NAME}")
    print(f"GROQ_API_KEY exists: {bool(settings.GROQ_API_KEY)}")
    print(f"GROQ_MODEL: {settings.GROQ_MODEL}")