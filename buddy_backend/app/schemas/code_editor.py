# buddy_backend/app/schemas/code_editor.py
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

# Project schemas
class CodeProjectBase(BaseModel):
    name: str = Field(..., description="Project name")
    type: str = Field(..., description="Project type (flutter, python, nodejs, etc.)")
    language: str = Field(..., description="Primary programming language")

class CodeProjectCreate(CodeProjectBase):
    path: str = Field(..., description="Project directory path")
    template_id: str = Field(..., description="Template ID to use")
    config: Optional[Dict[str, Any]] = Field(default={}, description="Project configuration")

class CodeProjectUpdate(BaseModel):
    name: Optional[str] = None
    config: Optional[Dict[str, Any]] = None
    dependencies: Optional[List[str]] = None

class CodeProjectResponse(CodeProjectBase):
    id: str
    path: str
    main_file: str
    config: Dict[str, Any]
    dependencies: List[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# File schemas
class CodeFileBase(BaseModel):
    path: str = Field(..., description="File path relative to project")
    name: str = Field(..., description="File name")
    language: str = Field(..., description="Programming language")

class CodeFileCreate(CodeFileBase):
    content: str = Field(default="", description="File content")

class CodeFileUpdate(BaseModel):
    content: str = Field(..., description="Updated file content")

class CodeFileResponse(CodeFileBase):
    id: str
    project_id: str
    content: str
    last_modified: datetime
    created_at: datetime

    class Config:
        from_attributes = True

# Template schemas
class ProjectTemplateResponse(BaseModel):
    id: str
    name: str
    description: Optional[str]
    type: str
    language: str
    platforms: List[str]
    dependencies: List[str]
    config: Dict[str, Any]
    icon: Optional[str]

    class Config:
        from_attributes = True

# Build schemas
class BuildConfigurationBase(BaseModel):
    name: str = Field(..., description="Configuration name")
    command: str = Field(..., description="Build command")
    args: List[str] = Field(default=[], description="Command arguments")
    environment: Dict[str, str] = Field(default={}, description="Environment variables")
    working_directory: Optional[str] = Field(None, description="Working directory")

class BuildConfigurationCreate(BuildConfigurationBase):
    project_id: str = Field(..., description="Project ID")
    is_default: bool = Field(default=False, description="Is default configuration")

class BuildConfigurationResponse(BuildConfigurationBase):
    id: str
    project_id: str
    is_default: bool
    created_at: datetime

    class Config:
        from_attributes = True

class BuildExecutionResponse(BaseModel):
    id: str
    project_id: str
    config_id: Optional[str]
    status: str
    exit_code: Optional[int]
    output: Optional[str]
    error: Optional[str]
    build_time: Optional[int]
    started_at: datetime
    completed_at: Optional[datetime]

    class Config:
        from_attributes = True

# Sync schemas
class SyncConfigResponse(BaseModel):
    enabled: bool
    vscode_path: Optional[str]
    sync_extensions: List[str]
    settings: Dict[str, Any]
    auto_sync: bool
    sync_interval: int

class SyncStatusResponse(BaseModel):
    is_connected: bool
    vscode_connected: bool
    buddy_server_connected: bool
    last_sync: Optional[datetime]
    sync_errors: List[str]
    active_sessions: int

# Search schemas
class SearchRequest(BaseModel):
    query: str = Field(..., description="Search query")
    case_sensitive: bool = Field(default=False, description="Case sensitive search")
    use_regex: bool = Field(default=False, description="Use regular expressions")
    include_extensions: List[str] = Field(default=[], description="File extensions to include")
    exclude_directories: List[str] = Field(default=[".git", "node_modules", ".dart_tool"], description="Directories to exclude")

class SearchResult(BaseModel):
    file_path: str
    file_name: str
    line: int
    column: int
    content: str
    matched_text: str
    start_index: int
    end_index: int

class SearchResponse(BaseModel):
    query: str
    results: List[SearchResult]
    total_matches: int
    search_time: float

# Git schemas
class GitStatus(BaseModel):
    branch: str
    changes: List[Dict[str, Any]]
    has_remote: bool
    ahead_by: int
    behind_by: int

class GitCommitRequest(BaseModel):
    message: str = Field(..., description="Commit message")
    files: List[str] = Field(default=[], description="Files to commit (empty for all)")

class GitCommitResponse(BaseModel):
    commit_hash: str
    message: str
    files_changed: int
    timestamp: datetime

# Collaboration schemas
class CollaborationSessionBase(BaseModel):
    session_name: Optional[str] = Field(None, description="Session name")
    max_participants: int = Field(default=5, description="Maximum participants")

class CollaborationSessionCreate(CollaborationSessionBase):
    project_id: str = Field(..., description="Project ID")

class CollaborationSessionResponse(CollaborationSessionBase):
    id: str
    project_id: str
    host_user_id: str
    status: str
    created_at: datetime
    ended_at: Optional[datetime]

    class Config:
        from_attributes = True

class CollaborationParticipantBase(BaseModel):
    role: str = Field(default="collaborator", description="Participant role")
    permissions: Dict[str, bool] = Field(default={"read": True, "write": False, "build": False}, description="Permissions")

class CollaborationParticipantCreate(CollaborationParticipantBase):
    user_id: str = Field(..., description="User ID")

class CollaborationParticipantResponse(CollaborationParticipantBase):
    id: str
    session_id: str
    user_id: str
    status: str
    joined_at: datetime
    last_active: datetime

    class Config:
        from_attributes = True

# Analytics schemas
class ProjectAnalyticsResponse(BaseModel):
    metric_type: str
    metric_value: Dict[str, Any]
    timestamp: datetime

    class Config:
        from_attributes = True

class ProjectStatsResponse(BaseModel):
    total_lines: int
    total_files: int
    languages: Dict[str, int]
    last_build_time: Optional[int]
    test_coverage: Optional[float]
    commits_this_week: int
    build_success_rate: float

# Code snippet schemas
class CodeSnippetBase(BaseModel):
    name: str = Field(..., description="Snippet name")
    description: Optional[str] = Field(None, description="Snippet description")
    language: str = Field(..., description="Programming language")
    code: str = Field(..., description="Code content")
    tags: List[str] = Field(default=[], description="Tags")

class CodeSnippetCreate(CodeSnippetBase):
    is_public: bool = Field(default=False, description="Make snippet public")

class CodeSnippetUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    code: Optional[str] = None
    tags: Optional[List[str]] = None
    is_public: Optional[bool] = None

class CodeSnippetResponse(CodeSnippetBase):
    id: str
    user_id: str
    is_public: bool
    usage_count: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# WebSocket message schemas
class WSMessage(BaseModel):
    type: str = Field(..., description="Message type")
    data: Dict[str, Any] = Field(default={}, description="Message data")
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class WSFileSync(WSMessage):
    type: str = "file_sync"
    file_path: str
    content: str
    checksum: str

class WSProjectSync(WSMessage):
    type: str = "project_sync"
    project_id: str
    action: str  # created, updated, deleted

class WSCollaboration(WSMessage):
    type: str = "collaboration"
    session_id: str
    action: str  # user_joined, user_left, cursor_moved, text_changed

class WSVSCodeSync(WSMessage):
    type: str = "vscode_sync"
    action: str  # connect, disconnect, settings_changed, file_opened

# Error schemas
class CodeEditorError(BaseModel):
    error_type: str
    message: str
    details: Optional[Dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class ValidationError(CodeEditorError):
    error_type: str = "validation_error"
    field: str
    value: Any

class BuildError(CodeEditorError):
    error_type: str = "build_error"
    exit_code: int
    build_log: str

class SyncError(CodeEditorError):
    error_type: str = "sync_error"
    sync_type: str  # vscode, collaboration, backup

# Configuration schemas
class EditorPreferences(BaseModel):
    font_family: str = Field(default="Courier New", description="Font family")
    font_size: float = Field(default=14.0, description="Font size")
    enable_word_wrap: bool = Field(default=True, description="Enable word wrap")
    show_line_numbers: bool = Field(default=True, description="Show line numbers")
    enable_auto_complete: bool = Field(default=True, description="Enable auto complete")
    enable_syntax_highlighting: bool = Field(default=True, description="Enable syntax highlighting")
    theme: str = Field(default="dark", description="Editor theme")
    tab_size: int = Field(default=2, description="Tab size")
    insert_spaces: bool = Field(default=True, description="Insert spaces instead of tabs")
    enable_auto_save: bool = Field(default=True, description="Enable auto save")
    auto_save_interval: int = Field(default=30, description="Auto save interval in seconds")

class ProjectSettings(BaseModel):
    auto_build: bool = Field(default=False, description="Auto build on save")
    auto_test: bool = Field(default=False, description="Auto test on save")
    enable_linting: bool = Field(default=True, description="Enable linting")
    enable_formatting: bool = Field(default=True, description="Enable auto formatting")
    git_auto_stage: bool = Field(default=False, description="Auto stage changes")
    sync_enabled: bool = Field(default=True, description="Enable synchronization")
    backup_enabled: bool = Field(default=True, description="Enable automatic backups")
    collaboration_enabled: bool = Field(default=False, description="Enable collaboration")

# Health check schema
class HealthCheckResponse(BaseModel):
    status: str
    service: str
    timestamp: datetime
    features: Dict[str, bool]
    version: Optional[str] = None
    uptime: Optional[int] = None
