from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.core.config import settings
from app.ai.model_loader import load_ai_model
import json
import re

router = APIRouter()

class BuddyQuery(BaseModel):
    prompt: str
    chat_history: Optional[List[Dict[str, str]]] = []

class TimelineQuery(BaseModel):
    project_description: str
    chat_history: Optional[List[Dict[str, str]]] = []

class CheckpointHelp(BaseModel):
    task_id: str
    checkpoint: str
    chat_history: Optional[List[Dict[str, str]]] = []

MODEL_NAME = settings.MODEL_NAME
MODEL_PATH = settings.MODEL_PATH

try:
    ai_model = load_ai_model(MODEL_NAME, MODEL_PATH)
except Exception as e:
    print(f"❌ Failed to load model: {e}")
    ai_model = None

@router.post("/buddy/ask")
async def ask_buddy(query: BuddyQuery):
    if ai_model is None:
        # Fallback response when model is not available
        return {"response": "I'm currently not available. The AI model is not loaded. Please try again later."}

    try:
        # Build context with chat history
        context = "You are Buddy, a helpful AI assistant. Previous conversation:\n"
        for msg in query.chat_history[-10:]:  # Last 10 messages for context
            role = "User" if msg.get('role') == 'user' else "Buddy"
            context += f"{role}: {msg.get('content', '')}\n"
        
        context += f"\nUser: {query.prompt}\nBuddy:"
        
        response = ai_model.generate_response(context)
        return {"response": response}
    except Exception as e:
        return {"response": f"I encountered an error: {str(e)}. Please try again."}

@router.post("/buddy/generate-timeline")
async def generate_project_timeline(query: TimelineQuery):
    if ai_model is None:
        # Fallback response
        return _fallback_timeline_response(query.project_description)

    try:
        prompt = f"""Create a detailed project timeline for: {query.project_description}

Please provide:
1. Estimated duration (in days/weeks)
2. Difficulty level (Easy/Medium/Hard)
3. List of tasks with title, description, and duration
4. Milestones and checkpoints

Format your response as a structured timeline that can be broken into manageable tasks."""

        response = ai_model.generate_response(prompt)
        
        # Parse AI response into structured data
        timeline_data = _parse_timeline_response(response, query.project_description)
        return timeline_data
        
    except Exception as e:
        return _fallback_timeline_response(query.project_description)

@router.post("/buddy/checkpoint-help")
async def get_checkpoint_help(query: CheckpointHelp):
    if ai_model is None:
        return {"help": "I'm currently not available to provide checkpoint help. Please try again later."}

    try:
        prompt = f"""The user is working on task {query.task_id} and has reached checkpoint: {query.checkpoint}

Please provide specific, actionable help for this checkpoint. Include:
1. What they should focus on at this stage
2. Common challenges and how to overcome them
3. Resources or tools that might help
4. Next steps after completing this checkpoint

Be encouraging and practical in your advice."""

        response = ai_model.generate_response(prompt)
        return {"help": response}
        
    except Exception as e:
        return {"help": f"Sorry, I couldn't provide help for this checkpoint: {str(e)}"}

def _fallback_timeline_response(project_description: str):
    """Fallback response when AI model is not available"""
    return {
        "timeline": [
            {"phase": "Planning", "duration": "2 days", "description": "Research and plan the project"},
            {"phase": "Development", "duration": "5 days", "description": "Main development work"},
            {"phase": "Testing", "duration": "2 days", "description": "Test and debug"},
            {"phase": "Deployment", "duration": "1 day", "description": "Deploy and finalize"}
        ],
        "estimated_duration": "1-2 weeks",
        "difficulty": "Medium",
        "tasks": [
            {
                "title": "Project Research",
                "description": f"Research requirements for: {project_description}",
                "duration": "1 day",
                "checkpoint": "research_complete"
            },
            {
                "title": "Setup Development Environment",
                "description": "Set up tools and environment needed for development",
                "duration": "0.5 days",
                "checkpoint": "environment_ready"
            },
            {
                "title": "Core Development",
                "description": "Implement main features and functionality",
                "duration": "4 days",
                "checkpoint": "core_complete"
            },
            {
                "title": "Testing & Bug Fixes",
                "description": "Test thoroughly and fix any issues found",
                "duration": "2 days",
                "checkpoint": "testing_complete"
            },
            {
                "title": "Final Polish",
                "description": "Final touches and optimization",
                "duration": "1 day",
                "checkpoint": "project_complete"
            }
        ]
    }

def _parse_timeline_response(ai_response: str, project_description: str):
    """Parse AI response into structured timeline data"""
    try:
        # Try to extract structured information from AI response
        lines = ai_response.split('\n')
        
        # Extract duration
        duration_match = re.search(r'(\d+)\s*(day|week|month)', ai_response.lower())
        estimated_duration = f"{duration_match.group(1)} {duration_match.group(2)}s" if duration_match else "1-2 weeks"
        
        # Extract difficulty
        difficulty = "Medium"
        if any(word in ai_response.lower() for word in ['easy', 'simple', 'basic']):
            difficulty = "Easy"
        elif any(word in ai_response.lower() for word in ['hard', 'complex', 'difficult', 'advanced']):
            difficulty = "Hard"
        
        # For now, return fallback with AI response included
        fallback = _fallback_timeline_response(project_description)
        fallback['ai_response'] = ai_response
        fallback['estimated_duration'] = estimated_duration
        fallback['difficulty'] = difficulty
        
        return fallback
        
    except Exception:
        return _fallback_timeline_response(project_description)
