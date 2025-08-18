"""
Database migration to add AI Personas table
Run this script to add the personas table to your existing database
"""

import asyncio
from app.core.database import engine, Base
from app.models.persona import AIPersona

async def add_personas_table():
    """Add the personas table to the database"""
    async with engine.begin() as conn:
        # Import all models to ensure they're registered
        from app.models import user, message, flow, task, persona
        
        # Create only the new personas table
        await conn.run_sync(AIPersona.__table__.create, checkfirst=True)
        print("✅ AI Personas table created successfully!")

if __name__ == "__main__":
    print("🔄 Adding AI Personas table to database...")
    asyncio.run(add_personas_table())
    print("✅ Migration completed!")
