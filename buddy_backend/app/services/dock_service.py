import asyncio
import json
import uuid
import socket
import subprocess
import platform
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.dock import DeviceCRUD, CommandCRUD, MacroCRUD, FileTransferCRUD, DeviceGroupCRUD
from app.schemas.dock import (
    DeviceCreate, DeviceUpdate, CommandCreate, MacroCreate, FileTransferCreate,
    DeviceGroupCreate, SystemAction, ProcessAction, NetworkScan
)

class DockService:
    """Cross-platform device management and control service"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.connected_devices = {}
        self.active_connections = {}
        
    async def get_user_devices(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all devices registered to a user"""
        try:
            devices = DeviceCRUD.get_devices_by_owner(self.db, user_id)
            return [
                {
                    "id": device.id,
                    "name": device.name,
                    "platform": device.platform,
                    "device_type": device.device_metadata.get("device_type", "unknown") if device.device_metadata else "unknown",
                    "is_online": device.status == "online",
                    "last_seen": device.last_seen.isoformat() if device.last_seen else None,
                    "ip_address": device.ip_address,
                    "port": device.port,
                    "capabilities": device.capabilities or {},
                    "metadata": device.device_metadata or {},
                    "status": device.status
                }
                for device in devices
            ]
        except Exception as e:
            print(f"Error getting user devices: {str(e)}")
            return []
        
    async def register_device(self, user_id: str, name: str, platform: str, 
                            ip_address: str, port: int = 8000,
                            capabilities: Dict[str, Any] = None) -> Dict[str, Any]:
        """Register a new device"""
        if capabilities is None:
            capabilities = {}
            
        device_create = DeviceCreate(
            name=name,
            platform=platform,
            ip_address=ip_address,
            port=port,
            capabilities=capabilities,
            metadata={"registered_via": "api", "device_type": platform.lower()}
        )
        
        device = DeviceCRUD.create_device(self.db, device_create, user_id)
        
        return {
            "id": device.id,
            "name": device.name,
            "platform": device.platform,
            "ip_address": device.ip_address,
            "port": device.port,
            "capabilities": device.capabilities,
            "registered_at": device.created_at.isoformat(),
            "status": device.status
        }
        
    async def get_device_details(self, device_id: str, user_id: int) -> Optional[Dict[str, Any]]:
        """Get detailed device information"""
        # Mock implementation
        device = self.connected_devices.get(device_id)
        if device and device.get('user_id') == user_id:
            return device
        return None
        
    async def remove_device(self, device_id: str, user_id: int) -> bool:
        """Remove a device"""
        device = self.connected_devices.get(device_id)
        if device and device.get('user_id') == user_id:
            del self.connected_devices[device_id]
            return True
        return False
        
    async def execute_command(self, device_id: str, command_type: str, 
                            command: str, parameters: Dict[str, Any], user_id: int) -> Dict[str, Any]:
        """Execute a command on a remote device"""
        try:
            device = await self.get_device_details(device_id, user_id)
            if not device:
                raise Exception("Device not found or access denied")
                
            # Mock command execution based on platform
            platform = device.get('platform', '').lower()
            
            if command_type == "system":
                return await self._execute_system_command(device, command, parameters)
            elif command_type == "file":
                return await self._execute_file_command(device, command, parameters)
            elif command_type == "app":
                return await self._execute_app_command(device, command, parameters)
            elif command_type == "network":
                return await self._execute_network_command(device, command, parameters)
            else:
                raise Exception(f"Unknown command type: {command_type}")
                
        except Exception as e:
            return {"success": False, "error": str(e)}
            
    async def _execute_system_command(self, device: Dict, command: str, params: Dict) -> Dict[str, Any]:
        """Execute system-level commands"""
        platform = device.get('platform', '').lower()
        
        commands = {
            "get_system_info": {
                "windows": "systeminfo",
                "macos": "system_profiler SPHardwareDataType",
                "linux": "uname -a && lscpu"
            },
            "get_processes": {
                "windows": "tasklist",
                "macos": "ps aux",
                "linux": "ps aux"
            },
            "shutdown": {
                "windows": "shutdown /s /t 0",
                "macos": "sudo shutdown -h now",
                "linux": "sudo shutdown -h now"
            },
            "restart": {
                "windows": "shutdown /r /t 0",
                "macos": "sudo shutdown -r now", 
                "linux": "sudo shutdown -r now"
            }
        }
        
        if command in commands and platform in commands[command]:
            # Mock execution result
            return {
                "success": True,
                "command": commands[command][platform],
                "result": f"Command '{command}' executed successfully on {device['name']}",
                "executed_at": datetime.now().isoformat()
            }
        else:
            return {
                "success": False,
                "error": f"Command '{command}' not supported on {platform}"
            }
            
    async def _execute_file_command(self, device: Dict, command: str, params: Dict) -> Dict[str, Any]:
        """Execute file operations"""
        if command == "list_files":
            path = params.get("path", "/")
            # Mock file listing
            return {
                "success": True,
                "path": path,
                "files": [
                    {"name": "Documents", "type": "folder", "size": None, "modified": "2025-01-15T10:30:00"},
                    {"name": "Downloads", "type": "folder", "size": None, "modified": "2025-01-14T16:45:00"},
                    {"name": "file1.txt", "type": "file", "size": 1024, "modified": "2025-01-10T12:00:00"},
                    {"name": "image.jpg", "type": "file", "size": 2048576, "modified": "2025-01-08T09:15:00"}
                ]
            }
        elif command == "download_file":
            return {
                "success": True,
                "message": f"File download initiated for {params.get('file_path')}",
                "download_url": f"/dock/devices/{device['id']}/files/download?path={params.get('file_path')}"
            }
        elif command == "upload_file":
            return {
                "success": True,
                "message": f"File upload completed to {params.get('destination')}",
            }
        return {"success": False, "error": f"Unknown file command: {command}"}
        
    async def _execute_app_command(self, device: Dict, command: str, params: Dict) -> Dict[str, Any]:
        """Execute application commands"""
        if command == "launch_app":
            app_name = params.get("app_name")
            return {
                "success": True,
                "message": f"Launched {app_name} on {device['name']}",
                "app_name": app_name,
                "pid": 12345  # Mock process ID
            }
        elif command == "close_app":
            app_name = params.get("app_name")
            return {
                "success": True,
                "message": f"Closed {app_name} on {device['name']}",
                "app_name": app_name
            }
        return {"success": False, "error": f"Unknown app command: {command}"}
        
    async def _execute_network_command(self, device: Dict, command: str, params: Dict) -> Dict[str, Any]:
        """Execute network commands"""
        if command == "ping":
            target = params.get("target", "8.8.8.8")
            return {
                "success": True,
                "target": target,
                "result": f"PING {target}: 4 packets transmitted, 4 received, 0% packet loss",
                "latency": "12.3ms"
            }
        elif command == "port_scan":
            target = params.get("target")
            return {
                "success": True,
                "target": target,
                "open_ports": [22, 80, 443, 8000],
                "closed_ports": [21, 23, 25]
            }
        return {"success": False, "error": f"Unknown network command: {command}"}
        
    async def browse_files(self, device_id: str, path: str, user_id: int) -> List[Dict[str, Any]]:
        """Browse files on a device"""
        # Mock file browser
        return [
            {"name": "..", "type": "parent", "path": "/", "size": None},
            {"name": "Desktop", "type": "folder", "path": f"{path}/Desktop", "size": None},
            {"name": "Documents", "type": "folder", "path": f"{path}/Documents", "size": None},
            {"name": "Downloads", "type": "folder", "path": f"{path}/Downloads", "size": None},
            {"name": "Pictures", "type": "folder", "path": f"{path}/Pictures", "size": None},
            {"name": "config.txt", "type": "file", "path": f"{path}/config.txt", "size": 2048},
        ]
        
    async def transfer_file(self, device_id: str, source: str, destination: str, user_id: int) -> Dict[str, Any]:
        """Transfer files between devices"""
        return {
            "success": True,
            "source": source,
            "destination": destination,
            "transfer_id": str(uuid.uuid4()),
            "status": "initiated",
            "progress": 0
        }
        
    async def system_control(self, device_id: str, action: str, user_id: int) -> Dict[str, Any]:
        """Control system functions"""
        valid_actions = ["shutdown", "restart", "sleep", "wake", "lock", "unlock"]
        
        if action not in valid_actions:
            return {"success": False, "error": f"Invalid action: {action}"}
            
        return {
            "success": True,
            "action": action,
            "message": f"System action '{action}' executed successfully",
            "executed_at": datetime.now().isoformat()
        }
        
    async def get_device_apps(self, device_id: str, user_id: int) -> List[Dict[str, Any]]:
        """Get installed applications on device"""
        # Mock applications list
        return [
            {"id": "chrome", "name": "Google Chrome", "version": "120.0.0.0", "running": True},
            {"id": "vscode", "name": "Visual Studio Code", "version": "1.85.0", "running": False},
            {"id": "spotify", "name": "Spotify", "version": "1.2.25", "running": True},
            {"id": "discord", "name": "Discord", "version": "0.0.309", "running": False},
        ]
        
    async def launch_app(self, device_id: str, app_id: str, user_id: int) -> Dict[str, Any]:
        """Launch an application"""
        return {
            "success": True,
            "app_id": app_id,
            "message": f"Application {app_id} launched successfully",
            "pid": 56789
        }
        
    async def get_user_macros(self, user_id: int) -> List[Dict[str, Any]]:
        """Get user's automation macros"""
        return [
            {
                "id": "macro_1",
                "name": "Morning Routine",
                "description": "Turn on PC, launch apps, check weather",
                "commands": [
                    {"device": "device_1", "action": "wake"},
                    {"device": "device_1", "action": "launch_app", "params": {"app": "chrome"}},
                    {"device": "device_2", "action": "launch_app", "params": {"app": "spotify"}}
                ],
                "trigger_conditions": {"time": "08:00", "days": ["monday", "tuesday", "wednesday", "thursday", "friday"]},
                "enabled": True
            },
            {
                "id": "macro_2",
                "name": "Shutdown All",
                "description": "Safely shutdown all devices",
                "commands": [
                    {"device": "device_1", "action": "shutdown"},
                    {"device": "device_2", "action": "shutdown"}
                ],
                "trigger_conditions": {},
                "enabled": True
            }
        ]
        
    async def create_macro(self, user_id: int, name: str, description: str, 
                         commands: List[Dict], target_devices: List[str], 
                         trigger_conditions: Dict) -> Dict[str, Any]:
        """Create a new automation macro"""
        macro = {
            "id": str(uuid.uuid4()),
            "name": name,
            "description": description,
            "commands": commands,
            "target_devices": target_devices,
            "trigger_conditions": trigger_conditions,
            "user_id": user_id,
            "created_at": datetime.now().isoformat(),
            "enabled": True
        }
        return macro
        
    async def execute_macro(self, macro_id: str, user_id: int) -> Dict[str, Any]:
        """Execute a macro"""
        return {
            "success": True,
            "macro_id": macro_id,
            "execution_id": str(uuid.uuid4()),
            "status": "executing",
            "started_at": datetime.now().isoformat(),
            "commands_executed": 0,
            "total_commands": 3
        }
        
    async def discover_network_devices(self) -> List[Dict[str, Any]]:
        """Discover devices on the local network"""
        return [
            {
                "ip": "192.168.1.100",
                "hostname": "GAMING-PC",
                "mac": "AA:BB:CC:DD:EE:FF",
                "ports": [22, 80, 3389],
                "device_type": "computer"
            },
            {
                "ip": "192.168.1.101", 
                "hostname": "MacBook-Pro",
                "mac": "11:22:33:44:55:66",
                "ports": [22, 80, 443],
                "device_type": "computer"
            },
            {
                "ip": "192.168.1.150",
                "hostname": "Smart-TV",
                "mac": "77:88:99:AA:BB:CC",
                "ports": [80, 8008],
                "device_type": "media_device"
            }
        ]
        
    async def get_real_time_status(self) -> List[Dict[str, Any]]:
        """Get real-time status of all devices"""
        devices = []
        for device_id, device in self.connected_devices.items():
            # Mock real-time data
            device_status = device.copy()
            device_status.update({
                "current_time": datetime.now().isoformat(),
                "network_status": "connected",
                "performance": {
                    "cpu": f"{hash(str(datetime.now())) % 100}%",
                    "memory": f"{hash(str(datetime.now().second)) % 100}%",
                    "network_io": f"{hash(str(datetime.now().microsecond)) % 1000} KB/s"
                }
            })
            devices.append(device_status)
        return devices
    
    async def register_or_update_device(self, user_id: str, device_id: str, **device_info) -> Dict[str, Any]:
        """Register a new device or update existing one for auto-registration"""
        try:
            # Extract device information
            system_info = device_info.get('system_info', {})
            device_type = device_info.get('device_type', 'desktop')
            capabilities = device_info.get('capabilities', {})
            
            # Check if device already exists
            devices = DeviceCRUD.get_devices_by_owner(self.db, user_id)
            existing_device = None
            
            hostname = system_info.get('hostname', 'unknown')
            for device in devices:
                if device.name == hostname:
                    existing_device = device
                    break
            
            if existing_device:
                # Update existing device
                update_data = DeviceUpdate(
                    ip_address=system_info.get('ip_address', existing_device.ip_address),
                    status="online",
                    last_seen=datetime.utcnow(),
                    capabilities=capabilities,
                    device_metadata={
                        **(existing_device.device_metadata or {}),
                        "device_type": device_type,
                        "last_auto_register": datetime.utcnow().isoformat(),
                        **system_info
                    }
                )
                
                updated_device = DeviceCRUD.update_device(self.db, existing_device.id, update_data)
                
                if updated_device:
                    return {
                        "id": updated_device.id,
                        "name": updated_device.name,
                        "platform": updated_device.platform,
                        "ip_address": updated_device.ip_address,
                        "port": updated_device.port,
                        "capabilities": updated_device.capabilities or {},
                        "status": updated_device.status,
                        "device_type": device_type,
                        "updated": True
                    }
            
            # Create new device if update failed or no existing device
            device_create = DeviceCreate(
                name=hostname,
                platform=system_info.get('platform', 'Unknown'),
                ip_address=system_info.get('ip_address', '127.0.0.1'),
                port=8000,
                capabilities=capabilities,
                device_metadata={
                    "device_type": device_type,
                    "registered_via": "auto_register",
                    "auto_register_time": datetime.utcnow().isoformat(),
                    **system_info
                }
            )
            
            device = DeviceCRUD.create_device(self.db, device_create, user_id)
            
            if device:
                return {
                    "id": device.id,
                    "name": device.name,
                    "platform": device.platform,
                    "ip_address": device.ip_address,
                    "port": device.port,
                    "capabilities": device.capabilities or {},
                    "status": device.status,
                    "device_type": device_type,
                    "created": True
                }
            else:
                raise Exception("Failed to create device")
                
        except Exception as e:
            print(f"Error in register_or_update_device: {str(e)}")
            raise Exception(f"Failed to register or update device: {str(e)}")
