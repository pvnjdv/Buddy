from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime
from app.dependencies import get_current_user
from app.models.user import User
from app.ai.buddy_ai import BuddyAI
import json

router = APIRouter()

# Initialize Buddy AI (with RAG service)
buddy_ai = BuddyAI()

class KnowledgeEntry(BaseModel):
    title: str
    content: str
    category: str = "general"
    tags: List[str] = []
    metadata: Dict[str, Any] = {}

class KnowledgeUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    tags: Optional[List[str]] = None
    metadata: Optional[Dict[str, Any]] = None

class KnowledgeResponse(BaseModel):
    success: bool
    message: str
    data: Optional[Any] = None

class KnowledgeSearch(BaseModel):
    query: str
    category: Optional[str] = None
    limit: int = 10

@router.post("/knowledge/add", response_model=KnowledgeResponse)
async def add_knowledge(
    knowledge: KnowledgeEntry,
    current_user: User = Depends(get_current_user)
):
    """
    Add custom knowledge to enhance Buddy's responses
    
    Body format:
    {
        "title": "Knowledge Title",
        "content": "Detailed content/information",
        "category": "personal|work|technical|project|general",
        "tags": ["tag1", "tag2"],
        "metadata": {
            "source": "user_input",
            "importance": "high|medium|low",
            "context_type": "fact|instruction|example|reference"
        }
    }
    """
    try:
        knowledge_dict = knowledge.dict()
        knowledge_dict["metadata"]["added_by"] = str(current_user.id)
        knowledge_dict["metadata"]["user_email"] = current_user.email
        
        knowledge_id = await buddy_ai.add_custom_knowledge(knowledge_dict)
        
        return KnowledgeResponse(
            success=True,
            message=f"Knowledge added successfully with ID: {knowledge_id}",
            data={"knowledge_id": knowledge_id}
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding knowledge: {str(e)}")

@router.get("/knowledge/list", response_model=KnowledgeResponse)
async def list_knowledge(
    category: Optional[str] = None,
    current_user: User = Depends(get_current_user)
):
    """List all knowledge entries, optionally filtered by category"""
    try:
        knowledge_list = await buddy_ai.list_knowledge(category)
        
        return KnowledgeResponse(
            success=True,
            message=f"Retrieved {len(knowledge_list)} knowledge entries",
            data={
                "knowledge": knowledge_list,
                "total_count": len(knowledge_list),
                "category_filter": category
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing knowledge: {str(e)}")

@router.post("/knowledge/search", response_model=KnowledgeResponse)
async def search_knowledge(
    search_request: KnowledgeSearch,
    current_user: User = Depends(get_current_user)
):
    """Search knowledge entries by query"""
    try:
        results = await buddy_ai.search_knowledge(
            search_request.query, 
            search_request.category
        )
        
        # Limit results
        limited_results = results[:search_request.limit]
        
        return KnowledgeResponse(
            success=True,
            message=f"Found {len(limited_results)} matching entries",
            data={
                "results": limited_results,
                "query": search_request.query,
                "total_found": len(results)
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error searching knowledge: {str(e)}")

@router.get("/knowledge/context/{query}", response_model=KnowledgeResponse)
async def get_relevant_context(
    query: str,
    limit: int = 5,
    current_user: User = Depends(get_current_user)
):
    """Get relevant context for a query (used by AI)"""
    try:
        context = await buddy_ai.get_relevant_context(query, limit)
        
        return KnowledgeResponse(
            success=True,
            message=f"Retrieved {len(context)} relevant contexts",
            data={
                "context": context,
                "query": query,
                "similarity_scores": [ctx.get('similarity_score', 0) for ctx in context]
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting context: {str(e)}")

@router.put("/knowledge/{knowledge_id}", response_model=KnowledgeResponse)
async def update_knowledge(
    knowledge_id: str,
    updates: KnowledgeUpdate,
    current_user: User = Depends(get_current_user)
):
    """Update existing knowledge entry"""
    try:
        # Filter out None values
        update_dict = {k: v for k, v in updates.dict().items() if v is not None}
        
        if not update_dict:
            raise HTTPException(status_code=400, detail="No valid updates provided")
        
        # Add update metadata
        if "metadata" not in update_dict:
            update_dict["metadata"] = {}
        update_dict["metadata"]["updated_by"] = str(current_user.id)
        update_dict["metadata"]["updated_at"] = datetime.now().isoformat()
        
        success = await buddy_ai.rag_service.update_knowledge(knowledge_id, update_dict)
        
        if not success:
            raise HTTPException(status_code=404, detail="Knowledge entry not found")
        
        return KnowledgeResponse(
            success=True,
            message=f"Knowledge {knowledge_id} updated successfully",
            data={"knowledge_id": knowledge_id}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating knowledge: {str(e)}")

@router.delete("/knowledge/{knowledge_id}", response_model=KnowledgeResponse)
async def delete_knowledge(
    knowledge_id: str,
    current_user: User = Depends(get_current_user)
):
    """Delete knowledge entry"""
    try:
        success = await buddy_ai.rag_service.delete_knowledge(knowledge_id)
        
        if not success:
            raise HTTPException(status_code=404, detail="Knowledge entry not found")
        
        return KnowledgeResponse(
            success=True,
            message=f"Knowledge {knowledge_id} deleted successfully",
            data={"knowledge_id": knowledge_id}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting knowledge: {str(e)}")

@router.get("/knowledge/stats", response_model=KnowledgeResponse)
async def get_knowledge_stats(
    current_user: User = Depends(get_current_user)
):
    """Get knowledge base statistics"""
    try:
        stats = await buddy_ai.rag_service.get_knowledge_stats()
        categories = await buddy_ai.rag_service.get_categories()
        
        return KnowledgeResponse(
            success=True,
            message="Knowledge base statistics retrieved",
            data={
                "stats": stats,
                "available_categories": categories
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting stats: {str(e)}")

@router.post("/knowledge/bulk-add", response_model=KnowledgeResponse)
async def bulk_add_knowledge(
    knowledge_list: List[KnowledgeEntry],
    current_user: User = Depends(get_current_user)
):
    """Add multiple knowledge entries at once"""
    try:
        added_ids = []
        errors = []
        
        for i, knowledge in enumerate(knowledge_list):
            try:
                knowledge_dict = knowledge.dict()
                knowledge_dict["metadata"]["added_by"] = str(current_user.id)
                knowledge_dict["metadata"]["bulk_import"] = True
                knowledge_dict["metadata"]["import_index"] = i
                
                knowledge_id = await buddy_ai.add_custom_knowledge(knowledge_dict)
                added_ids.append(knowledge_id)
                
            except Exception as e:
                errors.append(f"Entry {i} ({knowledge.title}): {str(e)}")
        
        return KnowledgeResponse(
            success=len(errors) == 0,
            message=f"Added {len(added_ids)} entries successfully" + (f", {len(errors)} errors" if errors else ""),
            data={
                "added_ids": added_ids,
                "errors": errors,
                "total_processed": len(knowledge_list)
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error in bulk add: {str(e)}")

# Import helper endpoint
@router.post("/knowledge/import-file", response_model=KnowledgeResponse)
async def import_knowledge_file(
    file_content: str,  # JSON string content
    current_user: User = Depends(get_current_user)
):
    """
    Import knowledge from JSON file content
    
    Expected JSON format:
    [
        {
            "title": "Knowledge Title",
            "content": "Content here",
            "category": "category_name",
            "tags": ["tag1", "tag2"],
            "metadata": {"source": "file_import", "importance": "high"}
        },
        ...
    ]
    """
    try:
        # Parse JSON content
        try:
            knowledge_data = json.loads(file_content)
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=400, detail=f"Invalid JSON format: {str(e)}")
        
        if not isinstance(knowledge_data, list):
            raise HTTPException(status_code=400, detail="JSON must contain an array of knowledge entries")
        
        # Convert to KnowledgeEntry objects and add
        knowledge_entries = []
        for entry in knowledge_data:
            try:
                knowledge_entries.append(KnowledgeEntry(**entry))
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Invalid entry format: {str(e)}")
        
        # Use bulk add
        return await bulk_add_knowledge(knowledge_entries, current_user)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error importing file: {str(e)}")
