"""
System control service for backend
Handles system operations, process management, and device information
"""
import asyncio
import subprocess
import psutil
import platform
import os
from typing import Dict, List, Optional, Any
import json
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

class SystemService:
    def __init__(self):
        self.platform = platform.system().lower()
    
    async def get_system_info(self) -> Dict[str, Any]:
        """Get comprehensive system information"""
        try:
            # Basic system info
            system_info = {
                'platform': platform.system(),
                'platform_version': platform.release(),
                'architecture': platform.machine(),
                'processor': platform.processor(),
                'hostname': platform.node(),
                'python_version': platform.python_version()
            }
            
            # CPU information
            cpu_info = {
                'physical_cores': psutil.cpu_count(logical=False),
                'total_cores': psutil.cpu_count(logical=True),
                'cpu_percent': psutil.cpu_percent(interval=1),
                'cpu_freq': psutil.cpu_freq()._asdict() if psutil.cpu_freq() else None
            }
            
            # Memory information
            memory = psutil.virtual_memory()
            memory_info = {
                'total': memory.total,
                'available': memory.available,
                'percent': memory.percent,
                'used': memory.used,
                'free': memory.free
            }
            
            # Disk information
            disk = psutil.disk_usage('/')
            disk_info = {
                'total': disk.total,
                'used': disk.used,
                'free': disk.free,
                'percent': (disk.used / disk.total) * 100
            }
            
            # Network information
            network_info = {}
            try:
                network_stats = psutil.net_io_counters()
                network_info = {
                    'bytes_sent': network_stats.bytes_sent,
                    'bytes_recv': network_stats.bytes_recv,
                    'packets_sent': network_stats.packets_sent,
                    'packets_recv': network_stats.packets_recv
                }
            except:
                pass
            
            # Boot time
            boot_time = datetime.fromtimestamp(psutil.boot_time())
            
            return {
                'success': True,
                'system': system_info,
                'cpu': cpu_info,
                'memory': memory_info,
                'disk': disk_info,
                'network': network_info,
                'boot_time': boot_time.isoformat(),
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting system info: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def get_running_processes(self, limit: Optional[int] = None) -> Dict[str, Any]:
        """Get list of running processes"""
        try:
            processes = []
            
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'status', 'create_time']):
                try:
                    process_info = proc.info
                    process_info['create_time'] = datetime.fromtimestamp(process_info['create_time']).isoformat()
                    processes.append(process_info)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            
            # Sort by CPU usage
            processes.sort(key=lambda x: x.get('cpu_percent', 0), reverse=True)
            
            if limit:
                processes = processes[:limit]
            
            return {
                'success': True,
                'processes': processes,
                'total_processes': len(processes),
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting processes: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def kill_process(self, pid: int, force: bool = False) -> Dict[str, Any]:
        """Kill a process by PID"""
        try:
            # Check if process exists
            if not psutil.pid_exists(pid):
                return {
                    'success': False,
                    'error': f'Process with PID {pid} does not exist'
                }
            
            # Get process info before killing
            try:
                proc = psutil.Process(pid)
                process_name = proc.name()
                process_status = proc.status()
            except psutil.NoSuchProcess:
                return {
                    'success': False,
                    'error': f'Process with PID {pid} no longer exists'
                }
            except psutil.AccessDenied:
                return {
                    'success': False,
                    'error': f'Access denied to process with PID {pid}'
                }
            
            # Kill the process
            try:
                proc = psutil.Process(pid)
                if force:
                    proc.kill()  # SIGKILL
                else:
                    proc.terminate()  # SIGTERM
                
                # Wait for process to terminate
                try:
                    proc.wait(timeout=5)
                except psutil.TimeoutExpired:
                    if not force:
                        # If terminate failed, try kill
                        proc.kill()
                        proc.wait(timeout=5)
                
                return {
                    'success': True,
                    'pid': pid,
                    'process_name': process_name,
                    'method': 'kill' if force else 'terminate',
                    'message': f'Process {process_name} (PID: {pid}) terminated successfully'
                }
                
            except psutil.NoSuchProcess:
                return {
                    'success': True,
                    'pid': pid,
                    'message': f'Process with PID {pid} was already terminated'
                }
            except psutil.AccessDenied:
                return {
                    'success': False,
                    'error': f'Access denied when trying to terminate process with PID {pid}'
                }
            
        except Exception as e:
            logger.error(f"Error killing process {pid}: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def execute_command(self, command: str, args: List[str] = None, timeout: int = 30) -> Dict[str, Any]:
        """Execute a system command"""
        try:
            if args is None:
                args = []
            
            # Security check - only allow safe commands
            safe_commands = [
                'ls', 'dir', 'pwd', 'whoami', 'date', 'uptime', 'df', 'free',
                'ps', 'top', 'htop', 'netstat', 'ifconfig', 'ping'
            ]
            
            if command not in safe_commands:
                return {
                    'success': False,
                    'error': f'Command "{command}" is not allowed for security reasons'
                }
            
            # Execute command
            process = await asyncio.create_subprocess_exec(
                command, *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            try:
                stdout, stderr = await asyncio.wait_for(
                    process.communicate(), 
                    timeout=timeout
                )
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()
                return {
                    'success': False,
                    'error': f'Command timed out after {timeout} seconds'
                }
            
            return {
                'success': process.returncode == 0,
                'command': command,
                'args': args,
                'exit_code': process.returncode,
                'stdout': stdout.decode('utf-8') if stdout else '',
                'stderr': stderr.decode('utf-8') if stderr else '',
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error executing command {command}: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def get_resource_usage(self) -> Dict[str, Any]:
        """Get current resource usage"""
        try:
            # CPU usage per core
            cpu_per_core = psutil.cpu_percent(percpu=True, interval=1)
            
            # Memory usage
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            # Disk I/O
            disk_io = psutil.disk_io_counters()
            
            # Network I/O
            network_io = psutil.net_io_counters()
            
            # Top processes by CPU
            top_cpu_processes = []
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent']):
                try:
                    if proc.info['cpu_percent'] > 0:
                        top_cpu_processes.append(proc.info)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            
            top_cpu_processes.sort(key=lambda x: x['cpu_percent'], reverse=True)
            top_cpu_processes = top_cpu_processes[:10]
            
            # Top processes by memory
            top_memory_processes = []
            for proc in psutil.process_iter(['pid', 'name', 'memory_percent']):
                try:
                    if proc.info['memory_percent'] > 0:
                        top_memory_processes.append(proc.info)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            
            top_memory_processes.sort(key=lambda x: x['memory_percent'], reverse=True)
            top_memory_processes = top_memory_processes[:10]
            
            return {
                'success': True,
                'cpu': {
                    'overall_percent': psutil.cpu_percent(),
                    'per_core': cpu_per_core,
                    'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else None
                },
                'memory': {
                    'virtual': {
                        'total': memory.total,
                        'used': memory.used,
                        'free': memory.free,
                        'percent': memory.percent
                    },
                    'swap': {
                        'total': swap.total,
                        'used': swap.used,
                        'free': swap.free,
                        'percent': swap.percent
                    }
                },
                'disk_io': {
                    'read_bytes': disk_io.read_bytes if disk_io else 0,
                    'write_bytes': disk_io.write_bytes if disk_io else 0,
                    'read_count': disk_io.read_count if disk_io else 0,
                    'write_count': disk_io.write_count if disk_io else 0
                },
                'network_io': {
                    'bytes_sent': network_io.bytes_sent if network_io else 0,
                    'bytes_recv': network_io.bytes_recv if network_io else 0,
                    'packets_sent': network_io.packets_sent if network_io else 0,
                    'packets_recv': network_io.packets_recv if network_io else 0
                },
                'top_processes': {
                    'cpu': top_cpu_processes,
                    'memory': top_memory_processes
                },
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting resource usage: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_disk_usage(self, path: str = '/') -> Dict[str, Any]:
        """Get disk usage for specified path"""
        try:
            if not os.path.exists(path):
                return {
                    'success': False,
                    'error': f'Path does not exist: {path}'
                }
            
            usage = psutil.disk_usage(path)
            
            return {
                'success': True,
                'path': path,
                'total': usage.total,
                'used': usage.used,
                'free': usage.free,
                'percent': (usage.used / usage.total) * 100
            }
            
        except Exception as e:
            logger.error(f"Error getting disk usage for {path}: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def list_disk_partitions(self) -> Dict[str, Any]:
        """List all disk partitions"""
        try:
            partitions = []
            
            for partition in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    partition_info = {
                        'device': partition.device,
                        'mountpoint': partition.mountpoint,
                        'fstype': partition.fstype,
                        'total': usage.total,
                        'used': usage.used,
                        'free': usage.free,
                        'percent': (usage.used / usage.total) * 100
                    }
                    partitions.append(partition_info)
                except PermissionError:
                    # Skip partitions we can't access
                    continue
            
            return {
                'success': True,
                'partitions': partitions
            }
            
        except Exception as e:
            logger.error(f"Error listing disk partitions: {e}")
            return {
                'success': False,
                'error': str(e)
            }
