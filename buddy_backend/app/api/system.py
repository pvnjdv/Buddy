"""
System control API endpoints
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.services.system_service import SystemService
from app.dependencies import get_current_user
from app.models.user import User
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/system", tags=["system"])

# Initialize system service
system_service = SystemService()

# Pydantic models for requests
class KillProcessRequest(BaseModel):
    pid: int
    force: bool = False

class ExecuteCommandRequest(BaseModel):
    command: str
    args: List[str] = []
    timeout: int = 30

class DiskUsageRequest(BaseModel):
    path: str = "/"

@router.get("/info")
async def get_system_info(
    current_user: User = Depends(get_current_user)
):
    """Get comprehensive system information"""
    try:
        logger.info(f"User {current_user.id} requesting system info")
        
        result = await system_service.get_system_info()
        
        return result
        
    except Exception as e:
        logger.error(f"Error in system info endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/processes")
async def get_running_processes(
    limit: Optional[int] = None,
    current_user: User = Depends(get_current_user)
):
    """Get list of running processes"""
    try:
        logger.info(f"User {current_user.id} requesting process list")
        
        result = await system_service.get_running_processes(limit=limit)
        
        return result
        
    except Exception as e:
        logger.error(f"Error in processes endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/kill-process")
async def kill_process(
    request: KillProcessRequest,
    current_user: User = Depends(get_current_user)
):
    """Kill a process by PID"""
    try:
        logger.info(f"User {current_user.id} requesting to kill process {request.pid}")
        
        result = await system_service.kill_process(request.pid, request.force)
        
        if result['success']:
            logger.info(f"Successfully killed process {request.pid}")
        else:
            logger.error(f"Failed to kill process {request.pid}: {result.get('error')}")
        
        return result
        
    except Exception as e:
        logger.error(f"Error in kill process endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/execute")
async def execute_command(
    request: ExecuteCommandRequest,
    current_user: User = Depends(get_current_user)
):
    """Execute a system command"""
    try:
        logger.info(f"User {current_user.id} requesting to execute: {request.command}")
        
        result = await system_service.execute_command(
            request.command,
            request.args,
            request.timeout
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Error in execute command endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/resources")
async def get_resource_usage(
    current_user: User = Depends(get_current_user)
):
    """Get current resource usage"""
    try:
        logger.info(f"User {current_user.id} requesting resource usage")
        
        result = await system_service.get_resource_usage()
        
        return result
        
    except Exception as e:
        logger.error(f"Error in resource usage endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/disk-usage")
async def get_disk_usage(
    request: DiskUsageRequest,
    current_user: User = Depends(get_current_user)
):
    """Get disk usage for specified path"""
    try:
        logger.info(f"User {current_user.id} requesting disk usage for {request.path}")
        
        result = system_service.get_disk_usage(request.path)
        
        return result
        
    except Exception as e:
        logger.error(f"Error in disk usage endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/partitions")
async def list_disk_partitions(
    current_user: User = Depends(get_current_user)
):
    """List all disk partitions"""
    try:
        logger.info(f"User {current_user.id} requesting disk partitions")
        
        result = system_service.list_disk_partitions()
        
        return result
        
    except Exception as e:
        logger.error(f"Error in partitions endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# System operations integrated into Buddy AI responses
@router.post("/buddy/system-operation")
async def execute_system_operation(
    operation: str,
    params: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """Execute system operations through Buddy AI"""
    try:
        logger.info(f"User {current_user.id} requesting system operation: {operation}")
        
        if operation == "get_info":
            result = await system_service.get_system_info()
        elif operation == "get_processes":
            result = await system_service.get_running_processes(
                limit=params.get("limit")
            )
        elif operation == "kill_process":
            result = await system_service.kill_process(
                params.get("pid"),
                params.get("force", False)
            )
        elif operation == "execute_command":
            result = await system_service.execute_command(
                params.get("command"),
                params.get("args", []),
                params.get("timeout", 30)
            )
        elif operation == "get_resources":
            result = await system_service.get_resource_usage()
        elif operation == "disk_usage":
            result = system_service.get_disk_usage(
                params.get("path", "/")
            )
        elif operation == "partitions":
            result = system_service.list_disk_partitions()
        else:
            return {
                'success': False,
                'error': f'Unknown system operation: {operation}'
            }
        
        # Add operation type for frontend processing
        result['operation_type'] = operation
        result['system_operation'] = True
        
        return result
        
    except Exception as e:
        logger.error(f"Error in system operation endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
