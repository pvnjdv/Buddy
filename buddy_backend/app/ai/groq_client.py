import asyncio
import httpx
from typing import Dict, Any, Optional
from app.core.config import settings

class GroqClient:
    """Groq API client for AI model interaction"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.groq.com/openai/v1"
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

    async def generate_response(self, prompt: str, model: str = None) -> str:
        """Generate response using Groq API"""
        if not model:
            model = settings.GROQ_MODEL
            
        # Ensure we're using a valid Groq model name (Production Models as of 2025)
        valid_models = [
            "llama-3.1-8b-instant",       # Meta - Fast, production ready
            "llama-3.3-70b-versatile",    # Meta - Latest Llama 3.3, larger model
            "meta-llama/llama-guard-4-12b",  # Meta - Content moderation model
            "whisper-large-v3",           # OpenAI - Speech-to-text
            "whisper-large-v3-turbo",     # OpenAI - Faster speech-to-text
        ]
        
        if model not in valid_models:
            model = "llama-3.1-8b-instant"  # Default to fast, reliable production model
            
        payload = {
            "model": model,
            "messages": [
                {
                    "role": "system", 
                    "content": "You are Buddy, a helpful AI assistant focused on project management and development guidance. Be encouraging, practical, and provide actionable advice."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "max_tokens": 512,
            "temperature": 0.7,
            "top_p": 0.95
        }
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self.headers,
                    json=payload,
                    timeout=30.0
                )
                
                # Log the response for debugging
                if response.status_code != 200:
                    error_text = response.text
                    print(f"Groq API Error {response.status_code}: {error_text}")
                    raise Exception(f"Groq API error {response.status_code}: {error_text}")
                
                data = response.json()
                return data["choices"][0]["message"]["content"].strip()
                
            except httpx.HTTPError as e:
                raise Exception(f"Groq API error: {str(e)}")
            except KeyError as e:
                raise Exception(f"Unexpected response format from Groq API: {str(e)}")
            except Exception as e:
                raise Exception(f"Failed to generate response: {str(e)}")

    async def generate_chat_completion(self, messages: list, model: str = None) -> str:
        """Generate chat completion with message history"""
        if not model:
            model = settings.GROQ_MODEL
            
        payload = {
            "model": model,
            "messages": messages,
            "max_tokens": 512,
            "temperature": 0.7,
            "top_p": 0.95
        }
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self.headers,
                    json=payload,
                    timeout=30.0
                )
                response.raise_for_status()
                
                data = response.json()
                return data["choices"][0]["message"]["content"].strip()
                
            except httpx.HTTPError as e:
                raise Exception(f"Groq API error: {str(e)}")
            except Exception as e:
                raise Exception(f"Failed to generate chat completion: {str(e)}")
