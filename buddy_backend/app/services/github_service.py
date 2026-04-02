"""
GitHub operations service for backend
Handles git commands and repository management
"""
import asyncio
import subprocess
import os
import re
from typing import Dict, List, Optional, Any
from pathlib import Path
from datetime import datetime
import json
import logging
import requests
from urllib.parse import urljoin

logger = logging.getLogger(__name__)

class GitHubService:
    def __init__(self):
        self.default_workspace = "/tmp/buddy_workspace"
        self.github_api_base = "https://api.github.com"
        # Get GitHub token from environment
        self.github_token = os.getenv("GITHUB_PAT")
        self.github_username = os.getenv("GITHUB_USERNAME", "buddy-ai")  # Default to buddy-ai account
        self.ensure_workspace()
    
    def ensure_workspace(self):
        """Ensure default workspace directory exists"""
        Path(self.default_workspace).mkdir(parents=True, exist_ok=True)
    
    def _get_github_headers(self) -> Dict[str, str]:
        """Get headers for GitHub API requests"""
        return {
            "Authorization": f"token {self.github_token}",
            "Accept": "application/vnd.github.v3+json",
            "Content-Type": "application/json"
        }
    
    async def create_github_repository(self, repo_name: str, description: str = "", private: bool = False) -> Dict[str, Any]:
        """Create a new repository on GitHub under the Buddy account"""
        try:
            if not self.github_token:
                raise Exception("GitHub PAT not configured")
            
            url = f"{self.github_api_base}/user/repos"
            data = {
                "name": repo_name,
                "description": description,
                "private": private,
                "auto_init": True  # Create initial commit with README
            }
            
            # Use requests in a thread pool since it's synchronous
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: requests.post(url, headers=self._get_github_headers(), json=data)
            )
            
            if response.status_code == 201:
                repo_data = response.json()
                return {
                    'success': True,
                    'repository': {
                        'id': repo_data['id'],
                        'name': repo_data['name'],
                        'full_name': repo_data['full_name'],
                        'html_url': repo_data['html_url'],
                        'ssh_url': repo_data['ssh_url'],
                        'clone_url': repo_data['clone_url']
                    }
                }
            else:
                error_msg = response.json().get('message', 'Unknown error')
                return {
                    'success': False,
                    'error': f"Failed to create repository: {error_msg}"
                }
                
        except Exception as e:
            logger.error(f"Error creating GitHub repository: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def create_flow_repository(self, user_mobile: str, project_name: str, description: str = "") -> Dict[str, Any]:
        """Create a repository for a flow with naming convention: {user_mobile}_{project_name}"""
        try:
            # Create repository name with convention
            repo_name = f"{user_mobile}_{project_name}".replace(" ", "_").lower()
            
            # Create on GitHub
            github_result = await self.create_github_repository(
                repo_name=repo_name,
                description=description,
                private=True  # Keep private for user projects
            )
            
            if not github_result['success']:
                return github_result
            
            # Clone locally for development
            clone_url = github_result['repository']['clone_url']
            local_path = os.path.join(self.default_workspace, repo_name)
            
            clone_result = await self.clone_repository(clone_url, local_path)
            
            if not clone_result['success']:
                return {
                    'success': False,
                    'error': f"Repository created on GitHub but failed to clone locally: {clone_result.get('error', 'Unknown error')}"
                }
            
            return {
                'success': True,
                'repository': github_result['repository'],
                'local_path': local_path,
                'repo_name': repo_name
            }
            
        except Exception as e:
            logger.error(f"Error creating flow repository: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    async def clone_repository(self, repo_url: str, target_dir: Optional[str] = None) -> Dict[str, Any]:
        """Clone a repository from GitHub"""
        try:
            if target_dir is None:
                # Extract repo name from URL
                repo_name = repo_url.split('/')[-1].replace('.git', '')
                target_dir = os.path.join(self.default_workspace, repo_name)
            
            # Ensure target directory parent exists
            os.makedirs(os.path.dirname(target_dir), exist_ok=True)
            
            # For private repositories, include PAT in the URL
            if self.github_token and 'https://' in repo_url:
                # Insert token into URL: https://oauth2:token@github.com/user/repo.git
                auth_url = repo_url.replace('https://', f'https://oauth2:{self.github_token}@')
            else:
                auth_url = repo_url
            
            # Execute git clone
            process = await asyncio.create_subprocess_exec(
                'git', 'clone', auth_url, target_dir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=self.default_workspace
            )
            
            stdout, stderr = await process.communicate()
            
            success = process.returncode == 0
            
            return {
                'success': success,
                'operation': 'clone',
                'repository_url': repo_url,
                'target_directory': target_dir,
                'output': stdout.decode('utf-8') if stdout else '',
                'error': stderr.decode('utf-8') if stderr else '',
                'exit_code': process.returncode
            }
            
        except Exception as e:
            logger.error(f"Error cloning repository: {e}")
            return {
                'success': False,
                'operation': 'clone',
                'repository_url': repo_url,
                'error': str(e)
            }
    
    async def commit_changes(self, repo_path: str, message: Optional[str] = None) -> Dict[str, Any]:
        """Commit changes in a repository"""
        try:
            if not os.path.exists(repo_path):
                return {
                    'success': False,
                    'operation': 'commit',
                    'error': f'Repository path does not exist: {repo_path}'
                }
            
            if message is None:
                message = f"Auto-commit by Buddy AI at {datetime.now().isoformat()}"
            
            # Add all changes
            add_process = await asyncio.create_subprocess_exec(
                'git', 'add', '.',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=repo_path
            )
            await add_process.communicate()
            
            # Commit changes
            commit_process = await asyncio.create_subprocess_exec(
                'git', 'commit', '-m', message,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=repo_path
            )
            
            stdout, stderr = await commit_process.communicate()
            
            success = commit_process.returncode == 0
            
            return {
                'success': success,
                'operation': 'commit',
                'repository_path': repo_path,
                'commit_message': message,
                'output': stdout.decode('utf-8') if stdout else '',
                'error': stderr.decode('utf-8') if stderr else '',
                'exit_code': commit_process.returncode
            }
            
        except Exception as e:
            logger.error(f"Error committing changes: {e}")
            return {
                'success': False,
                'operation': 'commit',
                'repository_path': repo_path,
                'error': str(e)
            }
    
    async def push_changes(self, repo_path: str, branch: str = 'main') -> Dict[str, Any]:
        """Push changes to remote repository"""
        try:
            if not os.path.exists(repo_path):
                return {
                    'success': False,
                    'operation': 'push',
                    'error': f'Repository path does not exist: {repo_path}'
                }
            
            # Push to remote
            process = await asyncio.create_subprocess_exec(
                'git', 'push', 'origin', branch,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=repo_path
            )
            
            stdout, stderr = await process.communicate()
            
            success = process.returncode == 0
            
            return {
                'success': success,
                'operation': 'push',
                'repository_path': repo_path,
                'branch': branch,
                'output': stdout.decode('utf-8') if stdout else '',
                'error': stderr.decode('utf-8') if stderr else '',
                'exit_code': process.returncode
            }
            
        except Exception as e:
            logger.error(f"Error pushing changes: {e}")
            return {
                'success': False,
                'operation': 'push',
                'repository_path': repo_path,
                'error': str(e)
            }
    
    async def pull_changes(self, repo_path: str) -> Dict[str, Any]:
        """Pull changes from remote repository"""
        try:
            if not os.path.exists(repo_path):
                return {
                    'success': False,
                    'operation': 'pull',
                    'error': f'Repository path does not exist: {repo_path}'
                }
            
            # Pull from remote
            process = await asyncio.create_subprocess_exec(
                'git', 'pull',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=repo_path
            )
            
            stdout, stderr = await process.communicate()
            
            success = process.returncode == 0
            
            return {
                'success': success,
                'operation': 'pull',
                'repository_path': repo_path,
                'output': stdout.decode('utf-8') if stdout else '',
                'error': stderr.decode('utf-8') if stderr else '',
                'exit_code': process.returncode
            }
            
        except Exception as e:
            logger.error(f"Error pulling changes: {e}")
            return {
                'success': False,
                'operation': 'pull',
                'repository_path': repo_path,
                'error': str(e)
            }
    
    async def get_status(self, repo_path: str) -> Dict[str, Any]:
        """Get repository status"""
        try:
            if not os.path.exists(repo_path):
                return {
                    'success': False,
                    'operation': 'status',
                    'error': f'Repository path does not exist: {repo_path}'
                }
            
            # Get git status
            process = await asyncio.create_subprocess_exec(
                'git', 'status', '--porcelain',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=repo_path
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                return {
                    'success': False,
                    'operation': 'status',
                    'repository_path': repo_path,
                    'error': stderr.decode('utf-8') if stderr else 'Unknown error'
                }
            
            # Parse git status output
            status_lines = stdout.decode('utf-8').strip().split('\n')
            files = []
            
            for line in status_lines:
                if line.strip():
                    status_code = line[:2]
                    filename = line[3:].strip()
                    files.append({
                        'file': filename,
                        'status': status_code,
                        'staged': status_code[0] != ' ',
                        'modified': status_code[1] != ' '
                    })
            
            return {
                'success': True,
                'operation': 'status',
                'repository_path': repo_path,
                'files': files,
                'has_changes': len(files) > 0
            }
            
        except Exception as e:
            logger.error(f"Error getting repository status: {e}")
            return {
                'success': False,
                'operation': 'status',
                'repository_path': repo_path,
                'error': str(e)
            }
    
    async def create_repository(self, repo_name: str, description: Optional[str] = None) -> Dict[str, Any]:
        """Create a new local repository (GitHub API integration would be added here)"""
        try:
            repo_path = os.path.join(self.default_workspace, repo_name)
            
            if os.path.exists(repo_path):
                return {
                    'success': False,
                    'operation': 'create_repository',
                    'error': f'Repository {repo_name} already exists'
                }
            
            # Create directory
            os.makedirs(repo_path, exist_ok=True)
            
            # Initialize git repository
            process = await asyncio.create_subprocess_exec(
                'git', 'init',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=repo_path
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                return {
                    'success': False,
                    'operation': 'create_repository',
                    'error': stderr.decode('utf-8') if stderr else 'Failed to initialize repository'
                }
            
            # Create README if description provided
            if description:
                readme_path = os.path.join(repo_path, 'README.md')
                with open(readme_path, 'w') as f:
                    f.write(f"# {repo_name}\n\n{description}\n")
                
                # Initial commit
                await self.commit_changes(repo_path, "Initial commit with README")
            
            return {
                'success': True,
                'operation': 'create_repository',
                'repository_name': repo_name,
                'repository_path': repo_path,
                'description': description,
                'output': stdout.decode('utf-8') if stdout else ''
            }
            
        except Exception as e:
            logger.error(f"Error creating repository: {e}")
            return {
                'success': False,
                'operation': 'create_repository',
                'repository_name': repo_name,
                'error': str(e)
            }
    
    def list_repositories(self) -> Dict[str, Any]:
        """List all local repositories"""
        try:
            repositories = []
            
            if os.path.exists(self.default_workspace):
                for item in os.listdir(self.default_workspace):
                    item_path = os.path.join(self.default_workspace, item)
                    if os.path.isdir(item_path):
                        git_path = os.path.join(item_path, '.git')
                        if os.path.exists(git_path):
                            repositories.append({
                                'name': item,
                                'path': item_path,
                                'is_git_repo': True
                            })
            
            return {
                'success': True,
                'operation': 'list_repositories',
                'repositories': repositories,
                'workspace': self.default_workspace
            }
            
        except Exception as e:
            logger.error(f"Error listing repositories: {e}")
            return {
                'success': False,
                'operation': 'list_repositories',
                'error': str(e)
            }
