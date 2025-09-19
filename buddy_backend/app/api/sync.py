from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Dict, Any
from datetime import datetime
import json

from ..core.database import get_db
from ..models.flow import ProjectFlow, Repository
from ..dependencies import get_current_user
from ..models.user import User

router = APIRouter()

# Store active WebSocket connections
active_connections: Dict[str, WebSocket] = {}

@router.websocket("/ws/sync")
async def websocket_sync(websocket: WebSocket, db: AsyncSession = Depends(get_db)):
    await websocket.accept()

    # Extract token from query parameters or headers
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # TODO: Validate token and get user
    # For now, accept all connections
    user_id = "temp_user_id"

    active_connections[user_id] = websocket

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)

            # Handle incoming messages
            if message.get("type") == "file_change":
                await handle_file_change(message, user_id, db)
            elif message.get("type") == "sync_request":
                await handle_sync_request(message, user_id, websocket, db)

    except WebSocketDisconnect:
        if user_id in active_connections:
            del active_connections[user_id]

@router.get("/projects")
async def get_projects(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all projects for the current user"""
    result = await db.execute(
        select(ProjectFlow)
        .options(select(ProjectFlow.repository))
        .filter(ProjectFlow.user_id == current_user.id)
    )
    flows = result.scalars().all()

    projects = []
    for flow in flows:
        project = {
            "id": flow.id,
            "name": flow.title,
            "description": flow.description,
            "repositoryUrl": flow.repository.html_url if flow.repository else None,
            "localPath": flow.repository.local_path if flow.repository else None,
            "lastModified": flow.updated_at.isoformat() if flow.updated_at else None
        }
        projects.append(project)

    return projects

@router.post("/sync/file-change")
async def sync_file_change(
    file_change: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Handle file change from VS Code extension"""
    project_id = file_change.get("projectId")
    path = file_change.get("path")
    content = file_change.get("content")
    action = file_change.get("action")
    timestamp = file_change.get("timestamp")

    # Find the project
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == project_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    project = result.scalar_one_or_none()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    # TODO: Store file change in database or handle sync logic
    # For now, just broadcast to other connected clients

    # Broadcast to other connected VS Code instances
    message = {
        "type": "file_changed",
        "data": {
            "projectId": project_id,
            "path": path,
            "content": content,
            "action": action,
            "timestamp": timestamp
        }
    }

    for user_id, connection in active_connections.items():
        if user_id != str(current_user.id):
            try:
                await connection.send_text(json.dumps(message))
            except Exception as e:
                print(f"Failed to send to {user_id}: {e}")

    return {"status": "synced"}

@router.post("/sync/project-update")
async def sync_project_update(
    project_update: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Handle project update from VS Code extension"""
    project_id = project_update.get("projectId")
    updates = project_update.get("updates", {})

    # Find and update the project
    result = await db.execute(
        select(ProjectFlow).filter(
            ProjectFlow.id == project_id,
            ProjectFlow.user_id == current_user.id
        )
    )
    project = result.scalar_one_or_none()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    # Update project fields
    for key, value in updates.items():
        if hasattr(project, key):
            setattr(project, key, value)

    project.updated_at = datetime.utcnow()
    await db.commit()

    # Broadcast update to other clients
    message = {
        "type": "project_updated",
        "data": {
            "id": project_id,
            **updates
        }
    }

    for user_id, connection in active_connections.items():
        if user_id != str(current_user.id):
            try:
                await connection.send_text(json.dumps(message))
            except Exception as e:
                print(f"Failed to send to {user_id}: {e}")

    return {"status": "updated"}

async def handle_file_change(message: Dict[str, Any], user_id: str, db: AsyncSession):
    """Handle file change from WebSocket"""
    # Process the file change similar to the REST endpoint
    await sync_file_change(message.get("data", {}), db=db)

async def handle_sync_request(message: Dict[str, Any], user_id: str, websocket: WebSocket, db: AsyncSession):
    """Handle sync request from WebSocket"""
    # Send current project state
    projects = await get_projects(db=db)
    response = {
        "type": "sync_response",
        "data": {
            "projects": projects
        }
    }
    await websocket.send_text(json.dumps(response))