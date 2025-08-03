from dotenv import load_dotenv
from pydantic_settings import BaseSettings
import os

load_dotenv()

class Settings(BaseSettings):
    APP_NAME: str = "Default App"
    SECRET_KEY: str = "insecure-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    MODEL_NAME: str = "mistral"
    MODEL_PATH: str = "/home/pvn/Desktop/Buddy/buddy_backend/app/models/llama/mistral-7b-instruct-v0.1.Q4_K_M.gguf"

    class Config:
        env_file = ".env"

settings = Settings()