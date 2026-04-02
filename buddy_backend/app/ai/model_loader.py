import os
from typing import List, Dict
from app.core.config import settings
from app.ai.groq_client import GroqClient

# Only import llama_cpp when needed to avoid Railway deployment issues
try:
    from llama_cpp import Llama
except ImportError:
    Llama = None
    print("Warning: llama_cpp not available, local model mode disabled")

class LlamaModelWrapper:
    def __init__(self, model_path: str):
        if Llama is None:
            raise ImportError("llama_cpp not available for local model")
        self.llm = Llama(
            model_path=model_path,
            n_ctx=512,  # Reduced context for faster inference
            n_threads=4,  # Reduced threads for stability
            n_gpu_layers=0,  # CPU only for compatibility
            verbose=False  # Reduced logging for cleaner output
        )

    def generate_response(self, prompt: str) -> str:
        prompt_template = f"[INST] {prompt} [/INST]"
        output = self.llm(
            prompt_template,
            max_tokens=128,  # Increased for better responses
            temperature=0.7,
            top_p=0.95,
            stop=["</s>"]
        )
        return output["choices"][0]["text"].strip()

class UnifiedAIClient:
    """Unified AI client supporting API, local, and creative modes"""
    
    def __init__(self):
        self.current_mode = "api"  # Default to API mode
        self.local_model = None
        self.groq_client = None
        
        # Initialize Groq client by default (API mode)
        self._init_groq_client()
    
    def _init_local_model(self, model_path: str = None):
        """Initialize local Llama model with custom path only"""
        try:
            if Llama is None:
                print("llama_cpp not available, cannot use local model")
                self.local_model = None
                return
                
            if model_path and not self.local_model:
                print(f"Loading local model from {model_path}")
                self.local_model = LlamaModelWrapper(model_path)
            elif not model_path:
                print("No model path provided for local mode")
                self.local_model = None
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
    
    def _enhance_prompt_for_submode(self, prompt: str, sub_mode: str) -> str:
        """Enhance prompt based on the selected submode"""
        if sub_mode == "ask":
            return f"As a knowledgeable assistant, please provide a direct and informative answer to this question: {prompt}"
        elif sub_mode == "agent":
            return f"As an intelligent agent, analyze this request and provide actionable solutions: {prompt}"
        elif sub_mode == "reasoning":
            return f"Please think through this step-by-step and provide logical reasoning for your response: {prompt}"
        elif sub_mode == "deepthink":
            return f"Take time to deeply analyze this complex topic. Provide comprehensive insights and detailed explanations: {prompt}"
        else:  # standard mode
            return prompt  # No modification for standard mode
    
    async def generate_response(self, prompt: str, chat_history: List[Dict[str, str]] = None, sub_mode: str = "standard") -> str:
        """Generate response using current mode (API, local, or creative) with optional chat history and submode"""
        try:
            # Modify prompt based on submode
            enhanced_prompt = self._enhance_prompt_for_submode(prompt, sub_mode)
            
            if self.current_mode == "creative":
                return await self._generate_creative_response(enhanced_prompt, chat_history)
            elif self.current_mode == "local":
                if not self.local_model:
                    raise Exception("No local model loaded. Please select a model file first.")
                if self.local_model:
                    # Local models don't support chat history in this implementation
                    return self.local_model.generate_response(enhanced_prompt)
                else:
                    raise Exception("Local model not available")
            elif self.current_mode == "api":
                if not self.groq_client:
                    self._init_groq_client()
                if self.groq_client:
                    return await self.groq_client.generate_response(enhanced_prompt, chat_history=chat_history)
                else:
                    raise Exception("Groq API client not available")
            
        except Exception as e:
            print(f"Error generating response in {self.current_mode} mode: {e}")
            # Fallback to the other mode if current fails
            return await self._try_fallback_mode(prompt, chat_history)

    async def _generate_creative_response(self, prompt: str, chat_history: List[Dict[str, str]] = None) -> str:
        """Generate creative responses using enhanced API mode with creative parameters"""
        try:
            if not self.groq_client:
                self._init_groq_client()
            
            # Use the Groq client but with creative parameters
            if self.groq_client:
                # For creative mode, we'll modify the prompt to be more creative
                creative_prompt = f"""Please provide a creative, detailed, and imaginative response to this request. Be expressive, use rich language, and think outside the box:

{prompt}

Response should be:
- Creative and imaginative
- Well-structured and detailed
- Engaging and thoughtful
- Original and insightful"""
                
                return await self.groq_client.generate_response(creative_prompt, chat_history=chat_history)
            else:
                raise Exception("Creative mode requires API access")
                
        except Exception as e:
            print(f"Error in creative mode: {e}")
            # Fallback to regular API mode
            return await self.groq_client.generate_response(prompt, chat_history=chat_history)
    
    async def _try_fallback_mode(self, prompt: str, chat_history: List[Dict[str, str]] = None) -> str:
        """Try the alternative mode if current mode fails"""
        try:
            fallback_mode = "api" if self.current_mode == "local" else "local"
            print(f"Trying fallback mode: {fallback_mode}")
            
            # Only try API fallback for local mode failures
            if fallback_mode == "api" and not self.groq_client:
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
        """Switch between API, local, and creative modes"""
        if new_mode not in ["local", "api", "creative"]:
            raise ValueError("Mode must be 'local', 'api', or 'creative'")
        
        self.current_mode = new_mode
        print(f"AI mode switched to: {new_mode}")
        
        # Pre-initialize the required client for the new mode
        if new_mode in ["api", "creative"]:
            self._init_groq_client()
        # For local mode, don't auto-initialize - wait for user to select model
    
    def switch_to_local_with_path(self, model_path: str):
        """Switch to local mode with a specific model file path"""
        import os
        
        # Validate the model file exists
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")
        
        try:
            # Clear existing local model to force reload with new path
            self.local_model = None
            
            # Switch to local mode
            self.current_mode = "local"
            
            # Initialize with new model path
            self._init_local_model(model_path)
            
            print(f"AI mode switched to local with custom model: {os.path.basename(model_path)}")
            
        except Exception as e:
            print(f"Failed to load custom model: {e}")
            raise

    def get_status(self):
        """Get current AI client status"""
        local_model_path = None
        if self.local_model and hasattr(self.local_model, 'llm') and hasattr(self.local_model.llm, 'model_path'):
            local_model_path = self.local_model.llm.model_path
            
        return {
            "current_mode": self.current_mode,
            "local_model_loaded": self.local_model is not None,
            "groq_client_available": self.groq_client is not None,
            "local_model_path": local_model_path
        }

def load_ai_model(model_name: str, model_path: str):
    print(f"Loading model: {model_name} from {model_path}")
    return LlamaModelWrapper(model_path)