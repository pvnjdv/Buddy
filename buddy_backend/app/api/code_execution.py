# app/api/code_execution.py
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Dict, List, Optional, AsyncGenerator
import subprocess
import asyncio
import os
import tempfile
import uuid
import json
from datetime import datetime
from app.dependencies import get_current_user
from app.models.user import User

router = APIRouter()

class CodeExecutionRequest(BaseModel):
    code: str
    language: str
    filename: Optional[str] = None
    arguments: Optional[List[str]] = []
    environment: Optional[Dict[str, str]] = {}
    working_directory: Optional[str] = None

class CodeExecutionResponse(BaseModel):
    execution_id: str
    status: str  # running, completed, error
    output: str
    error: str
    exit_code: Optional[int]
    execution_time: float
    created_at: datetime

class FileOperation(BaseModel):
    operation: str  # create, read, write, delete, rename, mkdir
    path: str
    content: Optional[str] = None
    new_path: Optional[str] = None

class FileOperationResponse(BaseModel):
    success: bool
    message: str
    content: Optional[str] = None
    files: Optional[List[Dict]] = None

# In-memory storage for execution results (use Redis in production)
execution_results: Dict[str, CodeExecutionResponse] = {}
active_processes: Dict[str, subprocess.Popen] = {}

def get_language_config(language: str) -> Dict:
    """Get configuration for different programming languages"""
    configs = {
        "python": {
            "extension": ".py",
            "command": ["python3"],
            "compiler": None
        },
        "dart": {
            "extension": ".dart",
            "command": ["dart", "run"],
            "compiler": None
        },
        "javascript": {
            "extension": ".js",
            "command": ["node"],
            "compiler": None
        },
        "typescript": {
            "extension": ".ts",
            "command": ["npx", "ts-node"],
            "compiler": ["npx", "tsc"]
        },
        "java": {
            "extension": ".java",
            "command": ["java"],
            "compiler": ["javac"]
        },
        "cpp": {
            "extension": ".cpp",
            "command": ["./a.out"],
            "compiler": ["g++", "-o", "a.out"]
        },
        "c": {
            "extension": ".c",
            "command": ["./a.out"],
            "compiler": ["gcc", "-o", "a.out"]
        },
        "go": {
            "extension": ".go",
            "command": ["go", "run"],
            "compiler": None
        },
        "rust": {
            "extension": ".rs",
            "command": ["./target/debug/main"],
            "compiler": ["rustc", "-o", "target/debug/main"]
        }
    }
    return configs.get(language.lower(), {
        "extension": ".txt",
        "command": ["cat"],
        "compiler": None
    })

async def execute_code_async(
    execution_id: str,
    code: str,
    language: str,
    filename: Optional[str],
    arguments: List[str],
    environment: Dict[str, str],
    working_directory: Optional[str]
):
    """Execute code asynchronously and store results"""
    start_time = datetime.now()
    
    try:
        config = get_language_config(language)
        
        # Create temporary directory for execution
        with tempfile.TemporaryDirectory() as temp_dir:
            if working_directory:
                exec_dir = working_directory
            else:
                exec_dir = temp_dir
            
            # Write code to file
            file_name = filename or f"main{config['extension']}"
            file_path = os.path.join(exec_dir, file_name)
            
            with open(file_path, 'w') as f:
                f.write(code)
            
            output = ""
            error = ""
            exit_code = 0
            
            # Compile if needed
            if config['compiler']:
                compile_cmd = config['compiler'] + [file_path]
                compile_process = await asyncio.create_subprocess_exec(
                    *compile_cmd,
                    cwd=exec_dir,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    env={**os.environ, **environment}
                )
                
                compile_stdout, compile_stderr = await compile_process.communicate()
                
                if compile_process.returncode != 0:
                    error = compile_stderr.decode()
                    exit_code = compile_process.returncode
                    execution_results[execution_id] = CodeExecutionResponse(
                        execution_id=execution_id,
                        status="error",
                        output="",
                        error=f"Compilation failed: {error}",
                        exit_code=exit_code,
                        execution_time=(datetime.now() - start_time).total_seconds(),
                        created_at=start_time
                    )
                    return
            
            # Execute code
            if language.lower() == "dart" and "flutter" in code.lower():
                # Special handling for Flutter projects
                cmd = ["flutter", "run", "--device-id=web-server", "--web-port=8080"]
            else:
                cmd = config['command']
                if config['command'][0] not in ['./a.out', './target/debug/main']:
                    cmd = cmd + [file_path] + arguments
                else:
                    cmd = cmd + arguments
            
            # Create and start process
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=exec_dir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env={**os.environ, **environment}
            )
            
            # Store process for potential termination
            active_processes[execution_id] = process
            
            # Wait for completion with timeout
            try:
                stdout, stderr = await asyncio.wait_for(
                    process.communicate(), 
                    timeout=30.0  # 30 second timeout
                )
                
                output = stdout.decode()
                error = stderr.decode()
                exit_code = process.returncode
                status = "completed" if exit_code == 0 else "error"
                
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()
                error = "Execution timed out (30 seconds)"
                exit_code = -1
                status = "error"
            
            finally:
                if execution_id in active_processes:
                    del active_processes[execution_id]
    
    except Exception as e:
        error = str(e)
        exit_code = -1
        status = "error"
    
    # Store results
    execution_results[execution_id] = CodeExecutionResponse(
        execution_id=execution_id,
        status=status,
        output=output,
        error=error,
        exit_code=exit_code,
        execution_time=(datetime.now() - start_time).total_seconds(),
        created_at=start_time
    )

@router.post("/execute", response_model=Dict[str, str])
async def execute_code(
    request: CodeExecutionRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user)
):
    """Execute code and return execution ID for tracking"""
    execution_id = str(uuid.uuid4())
    
    # Start execution in background
    background_tasks.add_task(
        execute_code_async,
        execution_id,
        request.code,
        request.language,
        request.filename,
        request.arguments or [],
        request.environment or {},
        request.working_directory
    )
    
    # Store initial status
    execution_results[execution_id] = CodeExecutionResponse(
        execution_id=execution_id,
        status="running",
        output="",
        error="",
        exit_code=None,
        execution_time=0.0,
        created_at=datetime.now()
    )
    
    return {"execution_id": execution_id, "status": "started"}

@router.get("/execution/{execution_id}", response_model=CodeExecutionResponse)
async def get_execution_result(
    execution_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get execution result by ID"""
    if execution_id not in execution_results:
        raise HTTPException(status_code=404, detail="Execution not found")
    
    return execution_results[execution_id]

@router.delete("/execution/{execution_id}")
async def stop_execution(
    execution_id: str,
    current_user: User = Depends(get_current_user)
):
    """Stop running execution"""
    if execution_id in active_processes:
        process = active_processes[execution_id]
        process.kill()
        await process.wait()
        del active_processes[execution_id]
        
        if execution_id in execution_results:
            execution_results[execution_id].status = "stopped"
        
        return {"message": "Execution stopped"}
    
    raise HTTPException(status_code=404, detail="No running execution found")

@router.post("/file-operation", response_model=FileOperationResponse)
async def file_operation(
    operation: FileOperation,
    current_user: User = Depends(get_current_user)
):
    """Perform file operations (create, read, write, delete, etc.)"""
    try:
        if operation.operation == "create":
            # Create new file
            with open(operation.path, 'w') as f:
                f.write(operation.content or "")
            return FileOperationResponse(
                success=True,
                message=f"File created: {operation.path}"
            )
        
        elif operation.operation == "read":
            # Read file content
            if not os.path.exists(operation.path):
                raise HTTPException(status_code=404, detail="File not found")
            
            with open(operation.path, 'r') as f:
                content = f.read()
            
            return FileOperationResponse(
                success=True,
                message="File read successfully",
                content=content
            )
        
        elif operation.operation == "write":
            # Write to file
            with open(operation.path, 'w') as f:
                f.write(operation.content or "")
            
            return FileOperationResponse(
                success=True,
                message=f"File saved: {operation.path}"
            )
        
        elif operation.operation == "delete":
            # Delete file
            if os.path.isfile(operation.path):
                os.remove(operation.path)
            elif os.path.isdir(operation.path):
                os.rmdir(operation.path)
            else:
                raise HTTPException(status_code=404, detail="File not found")
            
            return FileOperationResponse(
                success=True,
                message=f"Deleted: {operation.path}"
            )
        
        elif operation.operation == "rename":
            # Rename file
            if not operation.new_path:
                raise HTTPException(status_code=400, detail="New path required for rename")
            
            os.rename(operation.path, operation.new_path)
            
            return FileOperationResponse(
                success=True,
                message=f"Renamed: {operation.path} -> {operation.new_path}"
            )
        
        elif operation.operation == "mkdir":
            # Create directory
            os.makedirs(operation.path, exist_ok=True)
            
            return FileOperationResponse(
                success=True,
                message=f"Directory created: {operation.path}"
            )
        
        elif operation.operation == "list":
            # List directory contents
            if not os.path.isdir(operation.path):
                raise HTTPException(status_code=400, detail="Path is not a directory")
            
            files = []
            for item in os.listdir(operation.path):
                item_path = os.path.join(operation.path, item)
                files.append({
                    "name": item,
                    "path": item_path,
                    "type": "directory" if os.path.isdir(item_path) else "file",
                    "size": os.path.getsize(item_path) if os.path.isfile(item_path) else 0,
                    "modified": os.path.getmtime(item_path)
                })
            
            return FileOperationResponse(
                success=True,
                message="Directory listed successfully",
                files=files
            )
        
        else:
            raise HTTPException(status_code=400, detail="Invalid operation")
    
    except Exception as e:
        return FileOperationResponse(
            success=False,
            message=f"Operation failed: {str(e)}"
        )

@router.get("/languages")
async def get_supported_languages():
    """Get list of supported programming languages"""
    return {
        "languages": [
            {
                "name": "Python",
                "id": "python",
                "extension": ".py",
                "supports_execution": True,
                "supports_compilation": False
            },
            {
                "name": "Dart",
                "id": "dart",
                "extension": ".dart",
                "supports_execution": True,
                "supports_compilation": False
            },
            {
                "name": "JavaScript",
                "id": "javascript",
                "extension": ".js",
                "supports_execution": True,
                "supports_compilation": False
            },
            {
                "name": "TypeScript",
                "id": "typescript",
                "extension": ".ts",
                "supports_execution": True,
                "supports_compilation": True
            },
            {
                "name": "Java",
                "id": "java",
                "extension": ".java",
                "supports_execution": True,
                "supports_compilation": True
            },
            {
                "name": "C++",
                "id": "cpp",
                "extension": ".cpp",
                "supports_execution": True,
                "supports_compilation": True
            },
            {
                "name": "C",
                "id": "c",
                "extension": ".c",
                "supports_execution": True,
                "supports_compilation": True
            },
            {
                "name": "Go",
                "id": "go",
                "extension": ".go",
                "supports_execution": True,
                "supports_compilation": False
            },
            {
                "name": "Rust",
                "id": "rust",
                "extension": ".rs",
                "supports_execution": True,
                "supports_compilation": True
            }
        ]
    }

@router.get("/execution/{execution_id}/stream")
async def stream_execution_output(
    execution_id: str,
    current_user: User = Depends(get_current_user)
):
    """Stream execution output in real-time"""
    async def generate():
        while execution_id not in execution_results or execution_results[execution_id].status == "running":
            if execution_id in execution_results:
                result = execution_results[execution_id]
                yield f"data: {json.dumps(result.dict())}\n\n"
            
            await asyncio.sleep(0.5)  # Poll every 500ms
        
        # Send final result
        if execution_id in execution_results:
            result = execution_results[execution_id]
            yield f"data: {json.dumps(result.dict())}\n\n"
    
    return StreamingResponse(
        generate(), 
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )
