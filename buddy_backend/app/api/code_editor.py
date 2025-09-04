# buddy_backend/app/api/code_editor.py
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from typing import List, Dict, Any, Optional
import os
import json
import asyncio
import shutil
import subprocess
from pathlib import Path
import websockets
import logging
from datetime import datetime

from ..dependencies import get_db, get_current_user
from ..models.code_editor import CodeProject, CodeFile, SyncSession
from ..schemas.code_editor import (
    CodeProjectCreate, CodeProjectResponse, CodeFileCreate, 
    CodeFileResponse, ProjectTemplateResponse, SyncConfigResponse
)
from ..services.code_editor_service import CodeEditorService
from ..services.sync_service import SyncService

router = APIRouter(prefix="/code-editor", tags=["code-editor"])
logger = logging.getLogger(__name__)

# Initialize services
code_editor_service = CodeEditorService()
sync_service = SyncService()

@router.get("/templates", response_model=List[ProjectTemplateResponse])
async def get_project_templates():
    """Get available project templates"""
    try:
        templates = await code_editor_service.get_available_templates()
        return templates
    except Exception as e:
        logger.error(f"Error fetching templates: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/projects", response_model=CodeProjectResponse)
async def create_project(
    project: CodeProjectCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Create a new code project"""
    try:
        # Create project directory
        project_path = Path(project.path) / project.name
        project_path.mkdir(parents=True, exist_ok=True)
        
        # Create project based on template
        created_project = await code_editor_service.create_project_from_template(
            name=project.name,
            path=str(project_path),
            template_id=project.template_id,
            config=project.config or {},
            user_id=current_user["id"]
        )
        
        # Save to database
        db_project = CodeProject(
            id=created_project["id"],
            name=created_project["name"],
            path=created_project["path"],
            type=created_project["type"],
            language=created_project["language"],
            main_file=created_project["main_file"],
            config=created_project["config"],
            dependencies=created_project["dependencies"],
            user_id=current_user["id"]
        )
        db.add(db_project)
        db.commit()
        db.refresh(db_project)
        
        logger.info(f"Project created: {project.name} for user {current_user['id']}")
        return created_project
        
    except Exception as e:
        logger.error(f"Error creating project: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/projects", response_model=List[CodeProjectResponse])
async def get_user_projects(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get all projects for the current user"""
    try:
        projects = db.query(CodeProject).filter(
            CodeProject.user_id == current_user["id"]
        ).all()
        
        return [
            {
                "id": p.id,
                "name": p.name,
                "path": p.path,
                "type": p.type,
                "language": p.language,
                "main_file": p.main_file,
                "config": p.config,
                "dependencies": p.dependencies,
                "created_at": p.created_at,
                "updated_at": p.updated_at
            }
            for p in projects
        ]
        
    except Exception as e:
        logger.error(f"Error fetching projects: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/projects/{project_id}", response_model=CodeProjectResponse)
async def get_project(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get a specific project"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        return {
            "id": project.id,
            "name": project.name,
            "path": project.path,
            "type": project.type,
            "language": project.language,
            "main_file": project.main_file,
            "config": project.config,
            "dependencies": project.dependencies,
            "created_at": project.created_at,
            "updated_at": project.updated_at
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching project: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/projects/{project_id}/files")
async def get_project_files(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get file tree for a project"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        file_tree = await code_editor_service.get_project_file_tree(project.path)
        return {"files": file_tree}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching project files: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/projects/{project_id}/files/{file_path:path}")
async def get_file_content(
    project_id: str,
    file_path: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get content of a specific file"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        full_path = Path(project.path) / file_path
        if not full_path.exists():
            raise HTTPException(status_code=404, detail="File not found")
        
        # Security check - ensure file is within project directory
        if not str(full_path.resolve()).startswith(str(Path(project.path).resolve())):
            raise HTTPException(status_code=403, detail="Access denied")
        
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        return {
            "path": file_path,
            "name": full_path.name,
            "content": content,
            "language": code_editor_service.detect_language(full_path.name),
            "last_modified": datetime.fromtimestamp(full_path.stat().st_mtime).isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error reading file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/projects/{project_id}/files/{file_path:path}")
async def save_file_content(
    project_id: str,
    file_path: str,
    content: Dict[str, str],
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Save content to a specific file"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        full_path = Path(project.path) / file_path
        
        # Security check
        if not str(full_path.resolve()).startswith(str(Path(project.path).resolve())):
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Create directories if they don't exist
        full_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Save file
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content.get("content", ""))
        
        # Trigger sync if enabled
        await sync_service.file_changed(str(full_path), current_user["id"])
        
        return {
            "status": "success",
            "message": f"File {file_path} saved successfully",
            "last_modified": datetime.fromtimestamp(full_path.stat().st_mtime).isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error saving file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/projects/{project_id}/build")
async def build_project(
    project_id: str,
    build_config: Optional[Dict[str, Any]] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Build a project"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        result = await code_editor_service.build_project(
            project_path=project.path,
            project_type=project.type,
            config=build_config or {}
        )
        
        return {
            "status": "success" if result["exit_code"] == 0 else "failed",
            "exit_code": result["exit_code"],
            "output": result["output"],
            "error": result["error"],
            "build_time": result["build_time"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error building project: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/projects/{project_id}/run")
async def run_project(
    project_id: str,
    run_config: Optional[Dict[str, Any]] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Run a project"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        result = await code_editor_service.run_project(
            project_path=project.path,
            project_type=project.type,
            config=run_config or {}
        )
        
        return {
            "status": "started",
            "process_id": result["process_id"],
            "message": f"Project {project.name} started successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error running project: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/projects/{project_id}/test")
async def test_project(
    project_id: str,
    test_config: Optional[Dict[str, Any]] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Run tests for a project"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        result = await code_editor_service.test_project(
            project_path=project.path,
            project_type=project.type,
            config=test_config or {}
        )
        
        return {
            "status": "success" if result["exit_code"] == 0 else "failed",
            "exit_code": result["exit_code"],
            "output": result["output"],
            "error": result["error"],
            "test_results": result.get("test_results", {}),
            "test_time": result["test_time"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error testing project: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/projects/{project_id}/search")
async def search_in_project(
    project_id: str,
    search_params: Dict[str, Any],
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Search for text in project files"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        results = await code_editor_service.search_in_project(
            project_path=project.path,
            query=search_params.get("query", ""),
            case_sensitive=search_params.get("case_sensitive", False),
            use_regex=search_params.get("use_regex", False),
            include_extensions=search_params.get("include_extensions", [])
        )
        
        return {"results": results}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error searching project: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.websocket("/sync/{user_id}")
async def websocket_sync_endpoint(websocket: WebSocket, user_id: str):
    """WebSocket endpoint for real-time synchronization"""
    await websocket.accept()
    
    try:
        # Register client with sync service
        await sync_service.register_client(user_id, websocket)
        
        while True:
            # Wait for messages from client
            data = await websocket.receive_json()
            
            # Handle different message types
            message_type = data.get("type")
            
            if message_type == "file_sync":
                await sync_service.handle_file_sync(user_id, data)
            elif message_type == "project_sync":
                await sync_service.handle_project_sync(user_id, data)
            elif message_type == "vscode_connect":
                await sync_service.handle_vscode_connection(user_id, data)
            elif message_type == "collaboration_start":
                await sync_service.start_collaboration_session(user_id, data)
            
    except WebSocketDisconnect:
        logger.info(f"Client {user_id} disconnected")
        await sync_service.unregister_client(user_id)
    except Exception as e:
        logger.error(f"WebSocket error for user {user_id}: {e}")
        await sync_service.unregister_client(user_id)

@router.get("/sync/status/{user_id}")
async def get_sync_status(
    user_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get synchronization status"""
    try:
        if current_user["id"] != user_id:
            raise HTTPException(status_code=403, detail="Access denied")
        
        status = await sync_service.get_sync_status(user_id)
        return status
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting sync status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/sync/vscode/install")
async def install_vscode_extension():
    """Helper endpoint to install Buddy VS Code extension"""
    try:
        # This would trigger installation of the Buddy VS Code extension
        result = await code_editor_service.install_vscode_extension()
        return {
            "status": "success",
            "message": "VS Code extension installation initiated",
            "details": result
        }
        
    except Exception as e:
        logger.error(f"Error installing VS Code extension: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/git/{project_id}/status")
async def get_git_status(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get Git status for a project"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        result = await code_editor_service.get_git_status(project.path)
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting git status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/git/{project_id}/commit")
async def git_commit(
    project_id: str,
    commit_data: Dict[str, Any],
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Commit changes to Git"""
    try:
        project = db.query(CodeProject).filter(
            CodeProject.id == project_id,
            CodeProject.user_id == current_user["id"]
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        result = await code_editor_service.git_commit(
            project_path=project.path,
            message=commit_data.get("message", ""),
            files=commit_data.get("files", [])
        )
        
        return {
            "status": "success",
            "commit_hash": result["commit_hash"],
            "message": "Changes committed successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error committing changes: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Health check endpoint
@router.get("/health")
async def health_check():
    """Health check for code editor service"""
    return {
        "status": "healthy",
        "service": "code-editor",
        "timestamp": datetime.now().isoformat(),
        "features": {
            "project_creation": True,
            "file_editing": True,
            "build_system": True,
            "version_control": True,
            "real_time_sync": True,
            "vs_code_integration": True
        }
    }
