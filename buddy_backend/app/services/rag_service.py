"""
RAG (Retrieval-Augmented Generation) Service for Custom Knowledge Management

This service allows you to feed custom information to Buddy AI for enhanced responses.
The system uses vector embeddings to find relevant context for user queries.

Usage:
1. Add custom information using add_knowledge()
2. Query relevant context using get_relevant_context()
3. The context is automatically used in AI responses

Knowledge Format:
{
    "id": "unique_identifier",
    "title": "Knowledge Title",
    "content": "Detailed content/information",
    "category": "category_name",  # e.g., "personal", "work", "technical", "project"
    "tags": ["tag1", "tag2", "tag3"],
    "metadata": {
        "source": "Source of information",
        "date_added": "2025-08-21",
        "importance": "high|medium|low",
        "context_type": "fact|instruction|example|reference"
    }
}

Example Knowledge Entries:
1. Personal Preference:
{
    "id": "pref_coding_style",
    "title": "Preferred Coding Style",
    "content": "I prefer using TypeScript with strict mode enabled. Always use arrow functions for simple operations. Prefer async/await over promises. Use meaningful variable names.",
    "category": "personal",
    "tags": ["coding", "typescript", "preferences"],
    "metadata": {
        "source": "user_preference",
        "importance": "high",
        "context_type": "instruction"
    }
}

2. Project Information:
{
    "id": "buddy_project_info",
    "title": "Buddy App Architecture",
    "content": "Buddy is a Flutter app with FastAPI backend. Uses SQLAlchemy for database, has AI services for intelligent responses, supports flow generation with checkpoints, alarms, and notes.",
    "category": "project",
    "tags": ["buddy", "architecture", "flutter", "fastapi"],
    "metadata": {
        "source": "project_documentation",
        "importance": "high",
        "context_type": "reference"
    }
}
"""

import asyncio
import json
import re
import uuid
from typing import List, Dict, Any, Optional
from datetime import datetime
import sqlite3
from pathlib import Path

class RAGService:
    """RAG Service for managing custom knowledge and context retrieval"""
    
    def __init__(self, db_path: str = "knowledge_base.db"):
        self.db_path = db_path
        self.initialize_database()
    
    def initialize_database(self):
        """Initialize the knowledge database"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS knowledge_base (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    category TEXT DEFAULT 'general',
                    tags TEXT,  -- JSON array of tags
                    metadata TEXT,  -- JSON metadata
                    embedding_summary TEXT,  -- Simple text-based embedding
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.commit()
    
    async def add_knowledge(self, knowledge: Dict[str, Any]) -> str:
        """
        Add knowledge to the RAG system
        
        Args:
            knowledge: Dictionary containing knowledge information
            
        Returns:
            str: ID of the added knowledge entry
        """
        # Generate ID if not provided
        if 'id' not in knowledge:
            knowledge['id'] = f"kb_{uuid.uuid4().hex[:8]}"
        
        # Validate required fields
        required_fields = ['title', 'content']
        for field in required_fields:
            if field not in knowledge:
                raise ValueError(f"Required field '{field}' missing")
        
        # Set defaults
        knowledge.setdefault('category', 'general')
        knowledge.setdefault('tags', [])
        knowledge.setdefault('metadata', {})
        
        # Add timestamp
        knowledge['metadata']['date_added'] = datetime.now().isoformat()
        
        # Create simple embedding summary (keywords + content preview)
        embedding_summary = self._create_embedding_summary(knowledge)
        
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT OR REPLACE INTO knowledge_base 
                (id, title, content, category, tags, metadata, embedding_summary, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            """, (
                knowledge['id'],
                knowledge['title'],
                knowledge['content'],
                knowledge['category'],
                json.dumps(knowledge['tags']),
                json.dumps(knowledge['metadata']),
                embedding_summary
            ))
            conn.commit()
        
        return knowledge['id']
    
    def _create_embedding_summary(self, knowledge: Dict[str, Any]) -> str:
        """Create a simple embedding summary for text-based similarity matching"""
        # Combine important text fields
        text_parts = [
            knowledge['title'],
            knowledge['content'][:500],  # First 500 chars
            knowledge['category'],
            ' '.join(knowledge.get('tags', []))
        ]
        
        # Add metadata text
        metadata = knowledge.get('metadata', {})
        if 'source' in metadata:
            text_parts.append(metadata['source'])
        if 'context_type' in metadata:
            text_parts.append(metadata['context_type'])
        
        # Create summary
        summary = ' '.join(filter(None, text_parts)).lower()
        
        # Extract keywords (simple approach)
        words = re.findall(r'\b\w{3,}\b', summary)
        unique_words = list(set(words))
        
        return ' '.join(unique_words[:50])  # Limit to 50 keywords
    
    async def get_relevant_context(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """
        Get relevant knowledge entries for a query
        
        Args:
            query: User query or context
            limit: Maximum number of results to return
            
        Returns:
            List of relevant knowledge entries
        """
        query_summary = self._create_query_summary(query)
        
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT id, title, content, category, tags, metadata, embedding_summary
                FROM knowledge_base
                ORDER BY created_at DESC
            """)
            
            results = []
            for row in cursor.fetchall():
                entry = {
                    'id': row[0],
                    'title': row[1],
                    'content': row[2],
                    'category': row[3],
                    'tags': json.loads(row[4]) if row[4] else [],
                    'metadata': json.loads(row[5]) if row[5] else {},
                    'embedding_summary': row[6]
                }
                
                # Calculate simple similarity score
                similarity = self._calculate_similarity(query_summary, entry['embedding_summary'])
                entry['similarity_score'] = similarity
                
                if similarity > 0.1:  # Minimum relevance threshold
                    results.append(entry)
            
            # Sort by similarity and return top results
            results.sort(key=lambda x: x['similarity_score'], reverse=True)
            return results[:limit]
    
    def _create_query_summary(self, query: str) -> str:
        """Create a summary for query matching"""
        query_lower = query.lower()
        words = re.findall(r'\b\w{3,}\b', query_lower)
        return ' '.join(set(words))
    
    def _calculate_similarity(self, query_summary: str, embedding_summary: str) -> float:
        """Calculate simple text similarity score"""
        if not query_summary or not embedding_summary:
            return 0.0
        
        query_words = set(query_summary.split())
        embedding_words = set(embedding_summary.split())
        
        if not query_words or not embedding_words:
            return 0.0
        
        # Jaccard similarity
        intersection = query_words.intersection(embedding_words)
        union = query_words.union(embedding_words)
        
        return len(intersection) / len(union) if union else 0.0
    
    async def update_knowledge(self, knowledge_id: str, updates: Dict[str, Any]) -> bool:
        """Update existing knowledge entry"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            # Get existing entry
            cursor.execute("SELECT * FROM knowledge_base WHERE id = ?", (knowledge_id,))
            row = cursor.fetchone()
            if not row:
                return False
            
            # Merge updates
            current = {
                'id': row[0],
                'title': row[1],
                'content': row[2],
                'category': row[3],
                'tags': json.loads(row[4]) if row[4] else [],
                'metadata': json.loads(row[5]) if row[5] else {}
            }
            
            current.update(updates)
            
            # Update embedding summary
            embedding_summary = self._create_embedding_summary(current)
            
            cursor.execute("""
                UPDATE knowledge_base 
                SET title = ?, content = ?, category = ?, tags = ?, 
                    metadata = ?, embedding_summary = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
            """, (
                current['title'],
                current['content'],
                current['category'],
                json.dumps(current['tags']),
                json.dumps(current['metadata']),
                embedding_summary,
                knowledge_id
            ))
            conn.commit()
            return True
    
    async def delete_knowledge(self, knowledge_id: str) -> bool:
        """Delete knowledge entry"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM knowledge_base WHERE id = ?", (knowledge_id,))
            conn.commit()
            return cursor.rowcount > 0
    
    async def list_knowledge(self, category: Optional[str] = None) -> List[Dict[str, Any]]:
        """List all knowledge entries, optionally filtered by category"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            if category:
                cursor.execute("""
                    SELECT id, title, content, category, tags, metadata 
                    FROM knowledge_base WHERE category = ?
                    ORDER BY created_at DESC
                """, (category,))
            else:
                cursor.execute("""
                    SELECT id, title, content, category, tags, metadata 
                    FROM knowledge_base 
                    ORDER BY created_at DESC
                """)
            
            results = []
            for row in cursor.fetchall():
                results.append({
                    'id': row[0],
                    'title': row[1],
                    'content': row[2],
                    'category': row[3],
                    'tags': json.loads(row[4]) if row[4] else [],
                    'metadata': json.loads(row[5]) if row[5] else {}
                })
            
            return results
    
    async def search_knowledge(self, query: str, category: Optional[str] = None) -> List[Dict[str, Any]]:
        """Search knowledge entries by text query"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            query_pattern = f"%{query.lower()}%"
            
            if category:
                cursor.execute("""
                    SELECT id, title, content, category, tags, metadata 
                    FROM knowledge_base 
                    WHERE (LOWER(title) LIKE ? OR LOWER(content) LIKE ?) 
                    AND category = ?
                    ORDER BY created_at DESC
                """, (query_pattern, query_pattern, category))
            else:
                cursor.execute("""
                    SELECT id, title, content, category, tags, metadata 
                    FROM knowledge_base 
                    WHERE LOWER(title) LIKE ? OR LOWER(content) LIKE ?
                    ORDER BY created_at DESC
                """, (query_pattern, query_pattern))
            
            results = []
            for row in cursor.fetchall():
                results.append({
                    'id': row[0],
                    'title': row[1],
                    'content': row[2],
                    'category': row[3],
                    'tags': json.loads(row[4]) if row[4] else [],
                    'metadata': json.loads(row[5]) if row[5] else {}
                })
            
            return results
    
    async def get_categories(self) -> List[str]:
        """Get all available categories"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT DISTINCT category FROM knowledge_base ORDER BY category")
            return [row[0] for row in cursor.fetchall()]
    
    async def get_knowledge_stats(self) -> Dict[str, Any]:
        """Get knowledge base statistics"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            # Total count
            cursor.execute("SELECT COUNT(*) FROM knowledge_base")
            total_count = cursor.fetchone()[0]
            
            # By category
            cursor.execute("SELECT category, COUNT(*) FROM knowledge_base GROUP BY category")
            by_category = dict(cursor.fetchall())
            
            # Recent additions (last 7 days)
            cursor.execute("""
                SELECT COUNT(*) FROM knowledge_base 
                WHERE created_at >= datetime('now', '-7 days')
            """)
            recent_count = cursor.fetchone()[0]
            
            return {
                'total_entries': total_count,
                'by_category': by_category,
                'recent_additions': recent_count
            }


# Helper functions for easy knowledge management

def load_knowledge_from_file(file_path: str) -> List[Dict[str, Any]]:
    """
    Load knowledge entries from a JSON file
    
    File format:
    [
        {
            "title": "Knowledge Title",
            "content": "Content here",
            "category": "category_name",
            "tags": ["tag1", "tag2"],
            "metadata": {"source": "file", "importance": "high"}
        },
        ...
    ]
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            return json.load(file)
    except Exception as e:
        print(f"Error loading knowledge from file: {e}")
        return []

def save_knowledge_to_file(knowledge_list: List[Dict[str, Any]], file_path: str):
    """Save knowledge entries to a JSON file"""
    try:
        with open(file_path, 'w', encoding='utf-8') as file:
            json.dump(knowledge_list, file, indent=2, ensure_ascii=False)
        print(f"Knowledge saved to {file_path}")
    except Exception as e:
        print(f"Error saving knowledge to file: {e}")

async def bulk_add_knowledge(rag_service: RAGService, knowledge_list: List[Dict[str, Any]]) -> List[str]:
    """Add multiple knowledge entries"""
    ids = []
    for knowledge in knowledge_list:
        try:
            knowledge_id = await rag_service.add_knowledge(knowledge)
            ids.append(knowledge_id)
        except Exception as e:
            print(f"Error adding knowledge '{knowledge.get('title', 'Unknown')}': {e}")
    return ids
