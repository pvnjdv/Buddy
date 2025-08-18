from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from sqlalchemy.orm import selectinload
from typing import List, Optional
from app.models.persona import AIPersona
from app.schemas.persona import PersonaCreate, PersonaUpdate
import uuid

class PersonaCRUD:
    """CRUD operations for AI Personas"""
    
    async def create_persona(
        self, 
        db: AsyncSession, 
        persona_data: PersonaCreate, 
        user_id: str
    ) -> AIPersona:
        """Create a new AI persona for a user"""
        # Generate system prompt based on the persona description if not provided
        system_prompt = persona_data.system_prompt
        if not system_prompt and persona_data.description:
            system_prompt = f"""You are {persona_data.name}. {persona_data.description}

Key traits:
- Respond in character as {persona_data.name}
- Use a {persona_data.response_style or 'conversational'} tone
- Stay consistent with your described personality and expertise
- Be helpful while maintaining your unique character

Remember: You are {persona_data.name}, and you should embody this role in all your responses."""

        db_persona = AIPersona(
            id=str(uuid.uuid4()),
            user_id=user_id,
            name=persona_data.name,
            description=persona_data.description,
            system_prompt=system_prompt,
            personality_traits=persona_data.personality_traits,
            expertise_areas=persona_data.expertise_areas,
            response_style=persona_data.response_style,
            is_active=False,  # New personas are not active by default
            is_default=False
        )
        
        db.add(db_persona)
        await db.commit()
        await db.refresh(db_persona)
        return db_persona
    
    async def get_user_personas(self, db: AsyncSession, user_id: str) -> List[AIPersona]:
        """Get all personas for a user"""
        result = await db.execute(
            select(AIPersona)
            .where(AIPersona.user_id == user_id)
            .order_by(AIPersona.created_at.desc())
        )
        return result.scalars().all()
    
    async def get_active_persona(self, db: AsyncSession, user_id: str) -> Optional[AIPersona]:
        """Get the currently active persona for a user"""
        result = await db.execute(
            select(AIPersona)
            .where(AIPersona.user_id == user_id, AIPersona.is_active == True)
        )
        return result.scalars().first()
    
    async def get_persona_by_id(
        self, 
        db: AsyncSession, 
        persona_id: str, 
        user_id: str
    ) -> Optional[AIPersona]:
        """Get a specific persona by ID (must belong to the user)"""
        result = await db.execute(
            select(AIPersona)
            .where(AIPersona.id == persona_id, AIPersona.user_id == user_id)
        )
        return result.scalars().first()
    
    async def update_persona(
        self, 
        db: AsyncSession, 
        persona_id: str, 
        persona_data: PersonaUpdate,
        user_id: str
    ) -> Optional[AIPersona]:
        """Update a persona (only if it belongs to the user)"""
        # First check if the persona exists and belongs to the user
        existing_persona = await self.get_persona_by_id(db, persona_id, user_id)
        if not existing_persona:
            return None
        
        # Prepare update data
        update_data = {k: v for k, v in persona_data.dict(exclude_unset=True).items() if v is not None}
        
        # Update system prompt if description is being updated
        if 'description' in update_data and update_data['description']:
            update_data['system_prompt'] = f"""You are {update_data.get('name', existing_persona.name)}. {update_data['description']}

Key traits:
- Respond in character as {update_data.get('name', existing_persona.name)}
- Use a {update_data.get('response_style', existing_persona.response_style) or 'conversational'} tone
- Stay consistent with your described personality and expertise
- Be helpful while maintaining your unique character

Remember: You are {update_data.get('name', existing_persona.name)}, and you should embody this role in all your responses."""
        
        if update_data:
            await db.execute(
                update(AIPersona)
                .where(AIPersona.id == persona_id, AIPersona.user_id == user_id)
                .values(**update_data)
            )
            await db.commit()
            
            # Return updated persona
            return await self.get_persona_by_id(db, persona_id, user_id)
        
        return existing_persona
    
    async def delete_persona(
        self, 
        db: AsyncSession, 
        persona_id: str, 
        user_id: str
    ) -> bool:
        """Delete a persona (only if it belongs to the user and it's not default)"""
        # Check if persona exists and belongs to user
        existing_persona = await self.get_persona_by_id(db, persona_id, user_id)
        if not existing_persona or existing_persona.is_default:
            return False
        
        await db.execute(
            delete(AIPersona)
            .where(AIPersona.id == persona_id, AIPersona.user_id == user_id)
        )
        await db.commit()
        return True
    
    async def set_active_persona(
        self, 
        db: AsyncSession, 
        persona_id: Optional[str], 
        user_id: str
    ) -> bool:
        """Set a persona as active for a user (or clear active persona if persona_id is None)"""
        # First, deactivate all user's personas
        await db.execute(
            update(AIPersona)
            .where(AIPersona.user_id == user_id)
            .values(is_active=False)
        )
        
        # If persona_id is provided, activate that persona
        if persona_id:
            # Verify the persona exists and belongs to the user
            existing_persona = await self.get_persona_by_id(db, persona_id, user_id)
            if not existing_persona:
                return False
            
            await db.execute(
                update(AIPersona)
                .where(AIPersona.id == persona_id, AIPersona.user_id == user_id)
                .values(is_active=True)
            )
        
        await db.commit()
        return True
    
    async def create_default_personas(self, db: AsyncSession, user_id: str):
        """Create default AI personas for a new user"""
        default_personas = [
            {
                "name": "Teacher",
                "description": "Friendly primary school teacher who explains complex topics in simple, easy-to-understand ways. Patient, encouraging, and always ready to help students learn step by step.",
                "response_style": "educational",
                "expertise_areas": '["education", "teaching", "learning", "child development"]',
                "personality_traits": '["patient", "encouraging", "clear", "supportive"]'
            },
            {
                "name": "Developer",
                "description": "Experienced software developer with expertise in multiple programming languages and frameworks. Provides practical coding solutions, best practices, and technical guidance.",
                "response_style": "technical",
                "expertise_areas": '["programming", "software development", "coding", "technology"]',
                "personality_traits": '["analytical", "precise", "helpful", "solution-oriented"]'
            },
            {
                "name": "Writer",
                "description": "Creative and skilled writer who helps with content creation, editing, and improving written communication. Focuses on clarity, creativity, and engaging writing.",
                "response_style": "creative",
                "expertise_areas": '["writing", "content creation", "editing", "communication"]',
                "personality_traits": '["creative", "eloquent", "detailed", "inspiring"]'
            }
        ]
        
        for persona_data in default_personas:
            system_prompt = f"""You are {persona_data['name']}. {persona_data['description']}

Key traits:
- Respond in character as {persona_data['name']}
- Use a {persona_data['response_style']} tone
- Stay consistent with your described personality and expertise
- Be helpful while maintaining your unique character

Remember: You are {persona_data['name']}, and you should embody this role in all your responses."""
            
            db_persona = AIPersona(
                id=str(uuid.uuid4()),
                user_id=user_id,
                name=persona_data['name'],
                description=persona_data['description'],
                system_prompt=system_prompt,
                personality_traits=persona_data['personality_traits'],
                expertise_areas=persona_data['expertise_areas'],
                response_style=persona_data['response_style'],
                is_active=False,
                is_default=True
            )
            db.add(db_persona)
        
        await db.commit()

# Create a global instance
persona_crud = PersonaCRUD()
