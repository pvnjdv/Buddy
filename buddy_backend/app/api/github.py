"""
GitHub operations API endpoints
"""
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.services.github_service import GitHubService
from app.dependencies import get_current_user
from app.models.user import User
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/github", tags=["github"])

# Initialize GitHub service
github_service = GitHubService()

# Pydantic models for requests
class CloneRequest(BaseModel):
    repository_url: str
    target_directory: Optional[str] = None

class CommitRequest(BaseModel):
    repository_path: str
    commit_message: Optional[str] = None

class PushRequest(BaseModel):
    repository_path: str
    branch: str = "main"

class PullRequest(BaseModel):
    repository_path: str

class StatusRequest(BaseModel):
    repository_path: str

class CreateRepoRequest(BaseModel):
    repository_name: str
    description: Optional[str] = None

class CreateFlowRepoRequest(BaseModel):
    user_mobile: str
    project_name: str
    description: Optional[str] = None

@router.post("/create-flow-repo")
async def create_flow_repository(
    request: CreateFlowRepoRequest,
    current_user: User = Depends(get_current_user)
):
    """Create a GitHub repository for a flow with naming convention: {user_mobile}_{project_name}"""
    try:
        logger.info(f"User {current_user.id} creating flow repository: {request.user_mobile}_{request.project_name}")
        
        result = await github_service.create_flow_repository(
            user_mobile=request.user_mobile,
            project_name=request.project_name,
            description=request.description or f"Flow repository for {request.project_name}"
        )
        
        if result['success']:
            return {
                "success": True,
                "repository": result['repository'],
                "local_path": result['local_path'],
                "repo_name": result['repo_name']
            }
        else:
            raise HTTPException(status_code=400, detail=result['error'])
            
    except Exception as e:
        logger.error(f"Error creating flow repository: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/clone")
async def clone_repository(
    request: CloneRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user)
):
    """Clone a repository from GitHub"""
    try:
        logger.info(f"User {current_user.id} requesting clone: {request.repository_url}")
        
        # Execute clone operation
        result = await github_service.clone_repository(
            request.repository_url,
            request.target_directory
        )
        
        if result['success']:
            logger.info(f"Successfully cloned repository: {request.repository_url}")
        else:
            logger.error(f"Failed to clone repository: {result.get('error', 'Unknown error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error in clone endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/commit")
async def commit_changes(
    request: CommitRequest,
    current_user: User = Depends(get_current_user)
):
    """Commit changes in a repository"""
    try:
        logger.info(f"User {current_user.id} requesting commit: {request.repository_path}")
        
        result = await github_service.commit_changes(
            request.repository_path,
            request.commit_message
        )
        
        if result['success']:
            logger.info(f"Successfully committed changes: {request.repository_path}")
        else:
            logger.error(f"Failed to commit changes: {result.get('error', 'Unknown error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error in commit endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/push")
async def push_changes(
    request: PushRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user)
):
    """Push changes to remote repository"""
    try:
        logger.info(f"User {current_user.id} requesting push: {request.repository_path}")
        
        result = await github_service.push_changes(
            request.repository_path,
            request.branch
        )
        
        if result['success']:
            logger.info(f"Successfully pushed changes: {request.repository_path}")
        else:
            logger.error(f"Failed to push changes: {result.get('error', 'Unknown error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error in push endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/pull")
async def pull_changes(
    request: PullRequest,
    current_user: User = Depends(get_current_user)
):
    """Pull changes from remote repository"""
    try:
        logger.info(f"User {current_user.id} requesting pull: {request.repository_path}")
        
        result = await github_service.pull_changes(request.repository_path)
        
        if result['success']:
            logger.info(f"Successfully pulled changes: {request.repository_path}")
        else:
            logger.error(f"Failed to pull changes: {result.get('error', 'Unknown error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error in pull endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/status")
async def get_repository_status(
    request: StatusRequest,
    current_user: User = Depends(get_current_user)
):
    """Get repository status"""
    try:
        logger.info(f"User {current_user.id} requesting status: {request.repository_path}")
        
        result = await github_service.get_status(request.repository_path)
        
        return result
        
    except Exception as e:
        logger.error(f"Error in status endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/create")
async def create_repository(
    request: CreateRepoRequest,
    current_user: User = Depends(get_current_user)
):
    """Create a new repository"""
    try:
        logger.info(f"User {current_user.id} requesting create repo: {request.repository_name}")
        
        result = await github_service.create_repository(
            request.repository_name,
            request.description
        )
        
        if result['success']:
            logger.info(f"Successfully created repository: {request.repository_name}")
        else:
            logger.error(f"Failed to create repository: {result.get('error', 'Unknown error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error in create repository endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/repositories")
async def list_repositories(
    current_user: User = Depends(get_current_user)
):
    """List all local repositories"""
    try:
        logger.info(f"User {current_user.id} requesting repository list")
        
        result = github_service.list_repositories()
        
        return result
        
    except Exception as e:
        logger.error(f"Error in list repositories endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Git operations integrated into Buddy AI responses
@router.post("/buddy/git-operation")
async def execute_git_operation(
    operation: str,
    params: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """Execute git operations through Buddy AI"""
    try:
        logger.info(f"User {current_user.id} requesting git operation: {operation}")
        
        if operation == "clone":
            result = await github_service.clone_repository(
                params.get("repository_url"),
                params.get("target_directory")
            )
        elif operation == "commit":
            result = await github_service.commit_changes(
                params.get("repository_path"),
                params.get("commit_message")
            )
        elif operation == "push":
            result = await github_service.push_changes(
                params.get("repository_path"),
                params.get("branch", "main")
            )
        elif operation == "pull":
            result = await github_service.pull_changes(
                params.get("repository_path")
            )
        elif operation == "status":
            result = await github_service.get_status(
                params.get("repository_path")
            )
        elif operation == "create":
            result = await github_service.create_repository(
                params.get("repository_name"),
                params.get("description")
            )
        else:
            return {
                'success': False,
                'error': f'Unknown git operation: {operation}'
            }
        
        # Add operation type for frontend processing
        result['operation_type'] = operation
        result['git_operation'] = True
        
        return result
        
    except Exception as e:
        logger.error(f"Error in git operation endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
