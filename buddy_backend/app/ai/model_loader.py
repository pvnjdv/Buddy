
import os
from typing import List, Dict
from app.core.config import settings
from app.ai.groq_client import GroqClient

# Only import llama_cpp if we're using local mode to avoid Railway deployment issues
try:
    if settings.AI_MODE == "local":
        from llama_cpp import Llama
    else:
        Llama = None
except ImportError:
    Llama = None
    print("Warning: llama_cpp not available, local model mode disabled")

class LlamaModelWrapper:
    def __init__(self, model_path: str):
        if Llama is None:
            raise ImportError("llama_cpp not available for local model")
        self.llm = Llama(
            model_path=model_path,
            n_ctx=1024,
            n_threads=8,
            n_gpu_layers=15,
            verbose=True
        )

    def generate_response(self, prompt: str) -> str:
        prompt_template = f"[INST] {prompt} [/INST]"
        output = self.llm(
            prompt_template,
            max_tokens=64,
            temperature=0.7,
            top_p=0.95,
            stop=["</s>"]
        )
        return output["choices"][0]["text"].strip()

class UnifiedAIClient:
    """Unified AI client supporting both local and API modes"""
    
    def __init__(self):
        self.current_mode = settings.AI_MODE
        self.local_model = None
        self.groq_client = None
        
        # Initialize based on current mode
        if self.current_mode == "local":
            self._init_local_model()
        elif self.current_mode == "api":
            self._init_groq_client()
    
    def _init_local_model(self):
        """Initialize local Llama model"""
        try:
            if Llama is None:
                print("llama_cpp not available, cannot use local model")
                self.local_model = None
                return
                
            if not self.local_model:
                print(f"Loading local model: {settings.MODEL_NAME} from {settings.MODEL_PATH}")
                self.local_model = LlamaModelWrapper(settings.MODEL_PATH)
        except Exception as e:
            print(f"Failed to load local model: {e}")
            self.local_model = None
    
    def _init_groq_client(self):
        """Initialize Groq API client"""
        try:
            if not self.groq_client and settings.GROQ_API_KEY:
                self.groq_client = GroqClient(settings.GROQ_API_KEY)
        except Exception as e:
            print(f"Failed to initialize Groq client: {e}")
            self.groq_client = None
    
    async def generate_response(self, prompt: str, chat_history: List[Dict[str, str]] = None) -> str:
        """Generate response using current mode (local or API) with optional chat history"""
        try:
            if self.current_mode == "local":
                if not self.local_model:
                    self._init_local_model()
                if self.local_model:
                    # Local models don't support chat history in this implementation
                    return self.local_model.generate_response(prompt)
                else:
                    raise Exception("Local model not available")
            
            elif self.current_mode == "api":
                if not self.groq_client:
                    self._init_groq_client()
                if self.groq_client:
                    return await self.groq_client.generate_response(prompt, chat_history=chat_history)
                else:
                    raise Exception("Groq API client not available")
            
        except Exception as e:
            print(f"Error generating response in {self.current_mode} mode: {e}")
            # Fallback to the other mode if current fails
            return await self._try_fallback_mode(prompt, chat_history)
    
    async def _try_fallback_mode(self, prompt: str, chat_history: List[Dict[str, str]] = None) -> str:
        """Try the alternative mode if current mode fails"""
        try:
            fallback_mode = "api" if self.current_mode == "local" else "local"
            print(f"Trying fallback mode: {fallback_mode}")
            
            if fallback_mode == "local" and not self.local_model:
                self._init_local_model()
                if self.local_model:
                    return self.local_model.generate_response(prompt)
            
            elif fallback_mode == "api" and not self.groq_client:
                self._init_groq_client()
                if self.groq_client:
                    return await self.groq_client.generate_response(prompt, chat_history=chat_history)
            
        except Exception as e:
            print(f"Fallback mode also failed: {e}")
        
        # Final fallback - provide natural AI-like responses instead of templates
        return self._generate_natural_fallback(prompt)
    
    def _generate_natural_fallback(self, prompt: str) -> str:
        """Generate natural conversational responses when AI models fail"""
        prompt_lower = prompt.lower().strip()
        
        # Greetings
        if any(word in prompt_lower for word in ['hi', 'hello', 'hey']):
            return "Hello! I'm Buddy, your AI assistant. How can I help you today?"
        
        # How are you
        if any(phrase in prompt_lower for phrase in ['how are you', 'how\'s it going']):
            return "I'm doing well, thank you! I'm here to help you with whatever you need. What's on your mind?"
        
        # What questions  
        if any(phrase in prompt_lower for phrase in ['what can you', 'what do you', 'who are you']):
            return "I'm Buddy, your AI assistant! I can help with questions, provide guidance, and assist with project planning. What would you like to know?"
        
        # General conversational responses
        if len(prompt.strip()) < 20:  # Short messages
            return f"I understand you're asking about {prompt}. While my advanced AI is currently unavailable, I'm still here to help! What specifically would you like to know?"
        else:  # Longer messages
            return f"That's a thoughtful question! While I'm running in basic mode right now, I can still try to help. Could you tell me more about what you're looking for?"
    
    def switch_mode(self, new_mode: str):
        """Switch between local and api modes"""
        if new_mode not in ["local", "api"]:
            raise ValueError("Mode must be 'local' or 'api'")
        
        self.current_mode = new_mode
        print(f"AI mode switched to: {new_mode}")
        
        # Pre-initialize the required client for the new mode
        if new_mode == "local":
            self._init_local_model()
        elif new_mode == "api":
            self._init_groq_client()

def load_ai_model(model_name: str, model_path: str):
    print(f"Loading model: {model_name} from {model_path}")
    return LlamaModelWrapper(model_path)