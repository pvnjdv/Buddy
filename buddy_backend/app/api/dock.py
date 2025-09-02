from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Any, Optional
import json
import asyncio
import uuid
import platform
import socket
import psutil
from datetime import datetime, timedelta
from app.core.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.services.dock_service import DockService
from pydantic import BaseModel

router = APIRouter(tags=["Dock"])

# Dependency to get dock service with database session  
def get_dock_service(db: AsyncSession = Depends(get_db)) -> DockService:
    return DockService(db)

# Legacy Pydantic models for backward compatibility
class DeviceRegisterRequest(BaseModel):
    name: str
    platform: str
    device_type: str
    capabilities: Dict[str, Any] = {}

class MacroRequest(BaseModel):
    name: str
    description: str = ""
    commands: List[Dict[str, Any]]
    target_devices: List[str] = []
    trigger_conditions: Dict[str, Any] = {}

class CommandRequest(BaseModel):
    device_id: str
    command_type: str
    command: str
    parameters: Dict[str, Any] = {}

# Enhanced Pydantic models for auto-registration
class DeviceAutoRegisterRequest(BaseModel):
    device_name: Optional[str] = None
    platform: Optional[str] = None
    device_type: Optional[str] = None
    ip_address: Optional[str] = None
    capabilities: Dict[str, Any] = {}

class RemoteControlRequest(BaseModel):
    target_device_id: str
    control_type: str  # screen_share, mouse_control, keyboard_control, file_transfer
    action: str
    parameters: Dict[str, Any] = {}

class CrossPlatformCommand(BaseModel):
    device_id: str
    command_type: str  # system, app, file, network, input_control, screen_capture
    command: str
    parameters: Dict[str, Any] = {}
    execute_async: bool = True

# Enhanced connection manager for cross-platform control
class CrossPlatformManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.device_sessions: Dict[str, Dict[str, Any]] = {}
        self.user_devices: Dict[str, List[str]] = {}  # user_id -> [device_ids]
        
    async def connect_device(self, websocket: WebSocket, user_id: str, device_id: str, device_info: Dict[str, Any]):
        await websocket.accept()
        self.active_connections[device_id] = websocket
        self.device_sessions[device_id] = {
            "user_id": user_id,
            "device_info": device_info,
            "connected_at": datetime.now(),
            "last_heartbeat": datetime.now(),
            "status": "online"
        }
        
        # Add device to user's device list
        if user_id not in self.user_devices:
            self.user_devices[user_id] = []
        if device_id not in self.user_devices[user_id]:
            self.user_devices[user_id].append(device_id)
        
        # Notify other user devices about new device
        await self.broadcast_to_user_devices(user_id, {
            "type": "device_connected",
            "device_id": device_id,
            "device_info": device_info
        })

    def disconnect_device(self, device_id: str):
        if device_id in self.active_connections:
            session = self.device_sessions.get(device_id)
            if session:
                user_id = session["user_id"]
                # Remove from user devices
                if user_id in self.user_devices and device_id in self.user_devices[user_id]:
                    self.user_devices[user_id].remove(device_id)
                
                # Notify other devices
                asyncio.create_task(self.broadcast_to_user_devices(user_id, {
                    "type": "device_disconnected",
                    "device_id": device_id
                }))
            
            del self.active_connections[device_id]
            if device_id in self.device_sessions:
                del self.device_sessions[device_id]

    async def send_to_device(self, device_id: str, message: Dict[str, Any]):
        if device_id in self.active_connections:
            try:
                await self.active_connections[device_id].send_text(json.dumps(message))
                return True
            except:
                self.disconnect_device(device_id)
        return False

    async def broadcast_to_user_devices(self, user_id: str, message: Dict[str, Any]):
        user_device_ids = self.user_devices.get(user_id, [])
        for device_id in user_device_ids:
            await self.send_to_device(device_id, message)

    def get_user_devices_info(self, user_id: str) -> List[Dict[str, Any]]:
        devices = []
        user_device_ids = self.user_devices.get(user_id, [])
        for device_id in user_device_ids:
            if device_id in self.device_sessions:
                session = self.device_sessions[device_id]
                devices.append({
                    "device_id": device_id,
                    "device_info": session["device_info"],
                    "status": session["status"],
                    "connected_at": session["connected_at"].isoformat(),
                    "last_heartbeat": session["last_heartbeat"].isoformat()
                })
        return devices

manager = CrossPlatformManager()

# Auto-detect device information
def get_device_info() -> Dict[str, Any]:
    try:
        hostname = socket.gethostname()
        ip_address = socket.gethostbyname(hostname)
        
        # Get system information
        system_info = {
            "hostname": hostname,
            "ip_address": ip_address,
            "platform": platform.system(),
            "platform_release": platform.release(),
            "platform_version": platform.version(),
            "architecture": platform.machine(),
            "processor": platform.processor(),
        }
        
        # Get hardware info
        try:
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            system_info.update({
                "cpu_count": psutil.cpu_count(),
                "memory_total": memory.total,
                "memory_available": memory.available,
                "disk_total": disk.total,
                "disk_free": disk.free
            })
        except:
            pass
            
        # Determine device type
        if platform.system() in ["Windows", "Linux", "Darwin"]:
            device_type = "desktop"
        else:
            device_type = "mobile"
            
        # Set capabilities based on platform
        capabilities = {
            "screen_share": True,
            "remote_control": True,
            "file_transfer": True,
            "command_execution": True,
            "input_control": platform.system() in ["Windows", "Linux", "Darwin"],
            "webcam": True,
            "microphone": True
        }
        
        return {
            "name": hostname,
            "platform": platform.system(),
            "device_type": device_type,
            "system_info": system_info,
            "capabilities": capabilities
        }
    except Exception as e:
        return {
            "name": "Unknown Device",
            "platform": "Unknown",
            "device_type": "unknown",
            "system_info": {},
            "capabilities": {}
        }

# Device Management Endpoints
@router.post("/auto-register")
async def auto_register_device(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Auto-register current device when user logs in"""
    try:
        device_info = get_device_info()
        
        # Check if device already exists for this user
        existing_devices = await dock_service.get_user_devices(str(current_user.id))
        device_id = f"{current_user.id}_{device_info['system_info'].get('hostname', 'unknown')}"
        
        # Register or update device
        device = await dock_service.register_or_update_device(
            user_id=str(current_user.id),
            device_id=device_id,
            **device_info
        )
        
        return {
            "success": True, 
            "device": device, 
            "message": "Device auto-registered successfully",
            "device_id": device_id
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error auto-registering device: {str(e)}")

@router.get("/devices", response_model=Dict[str, Any])
async def get_user_devices(
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Get all devices registered to the current user with real-time status"""
    try:
        # Get devices from database
        db_devices = await dock_service.get_user_devices(str(current_user.id))
        
        # Get real-time device status from connection manager
        live_devices = manager.get_user_devices_info(str(current_user.id))
        
        # Merge database and live data
        device_map = {d["device_id"]: d for d in live_devices}
        for db_device in db_devices:
            device_id = db_device.get("id")
            if device_id in device_map:
                db_device["status"] = "online"
                db_device["last_seen"] = device_map[device_id]["last_heartbeat"]
            else:
                db_device["status"] = "offline"
        
        return {
            "devices": db_devices,
            "online_count": len(live_devices),
            "total_count": len(db_devices)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve devices: {str(e)}")

@router.post("/control/remote")
async def send_remote_control_command(
    request: RemoteControlRequest,
    current_user: User = Depends(get_current_user)
):
    """Send remote control command to target device"""
    try:
        # Verify target device belongs to user
        target_devices = manager.get_user_devices_info(str(current_user.id))
        target_device = next((d for d in target_devices if d["device_id"] == request.target_device_id), None)
        
        if not target_device:
            raise HTTPException(status_code=404, detail="Target device not found or not online")
        
        # Send command to target device
        command_message = {
            "type": "remote_control",
            "control_type": request.control_type,
            "action": request.action,
            "parameters": request.parameters,
            "timestamp": datetime.now().isoformat(),
            "source_user": str(current_user.id)
        }
        
        success = await manager.send_to_device(request.target_device_id, command_message)
        
        if success:
            return {"success": True, "message": f"Command sent to {target_device['device_info']['name']}"}
        else:
            raise HTTPException(status_code=503, detail="Failed to send command to target device")
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error sending remote command: {str(e)}")

@router.post("/control/cross-platform")
async def execute_cross_platform_command(
    request: CrossPlatformCommand,
    current_user: User = Depends(get_current_user)
):
    """Execute cross-platform command on target device"""
    try:
        command_message = {
            "type": "execute_command",
            "command_type": request.command_type,
            "command": request.command,
            "parameters": request.parameters,
            "execute_async": request.execute_async,
            "timestamp": datetime.now().isoformat()
        }
        
        success = await manager.send_to_device(request.device_id, command_message)
        
        if success:
            return {"success": True, "message": "Command executed successfully"}
        else:
            raise HTTPException(status_code=503, detail="Target device not available")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error executing command: {str(e)}")

# WebSocket endpoint for real-time device communication
@router.websocket("/connect/{device_id}")
async def websocket_device_connection(
    websocket: WebSocket, 
    device_id: str,
    token: str = None
):
    """WebSocket connection for real-time cross-platform device communication"""
    try:
        # Auto-register device info on connection
        device_info = get_device_info()
        user_id = "user_from_token"  # Extract from token in production
        
        # Connect device to manager
        await manager.connect_device(websocket, user_id, device_id, device_info)
        
        try:
            while True:
                # Receive messages from device
                data = await websocket.receive_text()
                message = json.loads(data)
                
                # Handle different message types
                if message.get("type") == "heartbeat":
                    # Update last heartbeat
                    if device_id in manager.device_sessions:
                        manager.device_sessions[device_id]["last_heartbeat"] = datetime.now()
                        await websocket.send_text(json.dumps({"type": "heartbeat_ack"}))
                        
                elif message.get("type") == "command_result":
                    # Forward command result to other user devices
                    await manager.broadcast_to_user_devices(user_id, {
                        "type": "command_completed",
                        "device_id": device_id,
                        "result": message.get("data")
                    })
                    
                elif message.get("type") == "screen_data":
                    # Forward screen sharing data to requesting device
                    target_device = message.get("target_device")
                    if target_device:
                        await manager.send_to_device(target_device, {
                            "type": "screen_update",
                            "source_device": device_id,
                            "screen_data": message.get("data")
                        })
                        
                elif message.get("type") == "input_event":
                    # Forward input events (mouse/keyboard) to target device
                    target_device = message.get("target_device")
                    if target_device:
                        await manager.send_to_device(target_device, {
                            "type": "input_control",
                            "source_device": device_id,
                            "event_type": message.get("event_type"),
                            "event_data": message.get("event_data")
                        })
                        
        except WebSocketDisconnect:
            manager.disconnect_device(device_id)
        except Exception as e:
            print(f"WebSocket error: {e}")
            manager.disconnect_device(device_id)
            
    except Exception as e:
        print(f"WebSocket connection error: {e}")
        await websocket.close()

@router.get("/devices/{device_id}")
async def get_device_details(
    device_id: str,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Get detailed information about a specific device"""
    try:
        device = await dock_service.get_device_details(device_id, current_user.id)
        if not device:
            raise HTTPException(status_code=404, detail="Device not found")
        return {"success": True, "device": device}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching device: {str(e)}")

@router.delete("/devices/{device_id}")
async def remove_device(
    device_id: str,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Remove a device from the dock"""
    try:
        success = await dock_service.remove_device(device_id, str(current_user.id))
        if not success:
            raise HTTPException(status_code=404, detail="Device not found")
        return {"success": True, "message": "Device removed successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error removing device: {str(e)}")

# Command Execution
@router.post("/execute")
async def execute_command(
    request: CommandRequest,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Execute a command on a remote device"""
    try:
        result = await dock_service.execute_command(
            device_id=request.device_id,
            command_type=request.command_type,
            command=request.command,
            parameters=request.parameters,
            user_id=str(current_user.id)
        )
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error executing command: {str(e)}")

# File Management
@router.get("/devices/{device_id}/files")
async def browse_device_files(
    device_id: str,
    path: str = "/",
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Browse files on a remote device"""
    try:
        files = await dock_service.browse_files(device_id, path, str(current_user.id))
        return {"success": True, "files": files, "current_path": path}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error browsing files: {str(e)}")

@router.post("/devices/{device_id}/files/transfer")
async def transfer_file(
    device_id: str,
    source_path: str,
    destination_path: str,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Transfer files between devices"""
    try:
        result = await dock_service.transfer_file(
            device_id, source_path, destination_path, str(current_user.id)
        )
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error transferring file: {str(e)}")

# System Control
@router.post("/devices/{device_id}/system/{action}")
async def system_control(
    device_id: str,
    action: str,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Control system functions on a device"""
    try:
        result = await dock_service.system_control(device_id, action, str(current_user.id))
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error controlling system: {str(e)}")

# Application Management
@router.get("/devices/{device_id}/apps")
async def get_device_apps(
    device_id: str,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Get installed applications on a device"""
    try:
        apps = await dock_service.get_device_apps(device_id, str(current_user.id))
        return {"apps": apps}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving apps: {str(e)}")

@router.post("/devices/{device_id}/apps/{app_id}/launch")
async def launch_app(
    device_id: str,
    app_id: str,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Launch an application on a device"""
    try:
        result = await dock_service.launch_app(device_id, app_id, str(current_user.id))
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error launching app: {str(e)}")

# Macro Management
@router.get("/macros")
async def get_user_macros(
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Get all macros for the current user"""
    try:
        macros = await dock_service.get_user_macros(str(current_user.id))
        return {"macros": macros}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving macros: {str(e)}")

@router.post("/macros")
async def create_macro(
    request: MacroRequest,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Create a new macro"""
    try:
        macro = await dock_service.create_macro(
            str(current_user.id),
            request.name,
            request.description,
            request.commands,
            request.target_devices,
            request.trigger_conditions
        )
        return {"success": True, "macro": macro}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating macro: {str(e)}")

@router.post("/macros/{macro_id}/execute")
async def execute_macro(
    macro_id: str,
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Execute a macro"""
    try:
        result = await dock_service.execute_macro(macro_id, str(current_user.id))
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error executing macro: {str(e)}")

# Device Discovery
@router.get("/discover")
async def discover_network_devices(
    current_user: User = Depends(get_current_user),
    dock_service: DockService = Depends(get_dock_service)
):
    """Discover devices on the local network"""
    try:
        devices = await dock_service.discover_network_devices()
        return {"devices": devices}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error discovering devices: {str(e)}")

# Command Execution
@router.post("/execute")
async def execute_command(
    request: CommandRequest,
    current_user: User = Depends(get_current_user)
):
    """Execute a command on a remote device"""
    try:
        result = await dock_service.execute_command(
            device_id=request.device_id,
            command_type=request.command_type,
            command=request.command,
            parameters=request.parameters,
            user_id=current_user.id
        )
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error executing command: {str(e)}")

# File Management
@router.get("/devices/{device_id}/files")
async def browse_device_files(
    device_id: str,
    path: str = "/",
    current_user: User = Depends(get_current_user)
):
    """Browse files on a remote device"""
    try:
        files = await dock_service.browse_files(device_id, path, current_user.id)
        return {"success": True, "files": files, "current_path": path}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error browsing files: {str(e)}")

@router.post("/devices/{device_id}/files/transfer")
async def transfer_file(
    device_id: str,
    source_path: str,
    destination_path: str,
    current_user: User = Depends(get_current_user)
):
    """Transfer files between devices"""
    try:
        result = await dock_service.transfer_file(
            device_id, source_path, destination_path, current_user.id
        )
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error transferring file: {str(e)}")

# System Control
@router.post("/devices/{device_id}/system/{action}")
async def system_control(
    device_id: str,
    action: str,  # shutdown, restart, sleep, wake, lock, unlock
    current_user: User = Depends(get_current_user)
):
    """Control system functions on remote device"""
    try:
        result = await dock_service.system_control(device_id, action, current_user.id)
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error executing system action: {str(e)}")

# Application Management
@router.get("/devices/{device_id}/apps")
async def get_device_apps(
    device_id: str,
    current_user: User = Depends(get_current_user)
):
    """Get list of installed applications on device"""
    try:
        apps = await dock_service.get_device_apps(device_id, current_user.id)
        return {"success": True, "apps": apps}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching apps: {str(e)}")

@router.post("/devices/{device_id}/apps/{app_id}/launch")
async def launch_app(
    device_id: str,
    app_id: str,
    current_user: User = Depends(get_current_user)
):
    """Launch an application on remote device"""
    try:
        result = await dock_service.launch_app(device_id, app_id, current_user.id)
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error launching app: {str(e)}")

# Macro Management
@router.get("/macros")
async def get_macros(current_user: User = Depends(get_current_user)):
    """Get all user macros"""
    try:
        macros = await dock_service.get_user_macros(current_user.id)
        return {"success": True, "macros": macros}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching macros: {str(e)}")

@router.post("/macros")
async def create_macro(
    request: MacroRequest,
    current_user: User = Depends(get_current_user)
):
    """Create a new automation macro"""
    try:
        macro = await dock_service.create_macro(
            user_id=current_user.id,
            name=request.name,
            description=request.description,
            commands=request.commands,
            target_devices=request.target_devices,
            trigger_conditions=request.trigger_conditions
        )
        return {"success": True, "macro": macro}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating macro: {str(e)}")

@router.post("/macros/{macro_id}/execute")
async def execute_macro(
    macro_id: str,
    current_user: User = Depends(get_current_user)
):
    """Execute a macro across multiple devices"""
    try:
        result = await dock_service.execute_macro(macro_id, current_user.id)
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error executing macro: {str(e)}")

# Network Discovery
@router.post("/discover")
async def discover_devices(current_user: User = Depends(get_current_user)):
    """Discover available devices on the network"""
    try:
        devices = await dock_service.discover_network_devices()
        return {"success": True, "discovered_devices": devices}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error discovering devices: {str(e)}")

# Real-time WebSocket endpoint
@router.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            # Handle different message types
            if message.get("type") == "device_status_request":
                # Send device status updates
                devices = await dock_service.get_real_time_status()
                await manager.send_personal_message(
                    json.dumps({"type": "device_status", "devices": devices}),
                    client_id
                )
            elif message.get("type") == "command":
                # Execute real-time command
                result = await dock_service.execute_command(
                    device_id=message.get("device_id"),
                    command_type=message.get("command_type"),
                    command=message.get("command"),
                    parameters=message.get("parameters", {}),
                    user_id=message.get("user_id")
                )
                await manager.send_personal_message(
                    json.dumps({"type": "command_result", "result": result}),
                    client_id
                )
                
    except WebSocketDisconnect:
        manager.disconnect(client_id)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(client_id)
