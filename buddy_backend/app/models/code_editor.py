# buddy_backend/app/models/code_editor.py
from sqlalchemy import Column, String, Text, JSON, DateTime, Integer, Boolean, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from ..core.database import Base

class CodeProject(Base):
    __tablename__ = "code_projects"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    path = Column(String, nullable=False)
    type = Column(String, nullable=False)  # flutter, python, nodejs, android, etc.
    language = Column(String, nullable=False)  # dart, python, javascript, etc.
    main_file = Column(String, nullable=False)
    config = Column(JSON, default={})
    dependencies = Column(JSON, default=[])
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    files = relationship("CodeFile", back_populates="project", cascade="all, delete-orphan")
    sync_sessions = relationship("SyncSession", back_populates="project", cascade="all, delete-orphan")

class CodeFile(Base):
    __tablename__ = "code_files"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("code_projects.id"), nullable=False)
    path = Column(String, nullable=False)  # Relative path within project
    name = Column(String, nullable=False)
    language = Column(String, nullable=False)
    content = Column(Text, default="")
    checksum = Column(String)  # For detecting changes
    last_modified = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    project = relationship("CodeProject", back_populates="files")

class SyncSession(Base):
    __tablename__ = "sync_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("code_projects.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    session_type = Column(String, nullable=False)  # vscode, collaboration, backup
    status = Column(String, default="active")  # active, paused, ended
    metadata = Column(JSON, default={})
    started_at = Column(DateTime, default=datetime.utcnow)
    ended_at = Column(DateTime)
    
    # Relationships
    project = relationship("CodeProject", back_populates="sync_sessions")
    sync_events = relationship("SyncEvent", back_populates="session", cascade="all, delete-orphan")

class SyncEvent(Base):
    __tablename__ = "sync_events"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String, ForeignKey("sync_sessions.id"), nullable=False)
    event_type = Column(String, nullable=False)  # file_change, project_change, build, etc.
    file_path = Column(String)
    old_content = Column(Text)
    new_content = Column(Text)
    metadata = Column(JSON, default={})
    timestamp = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    session = relationship("SyncSession", back_populates="sync_events")

class ProjectTemplate(Base):
    __tablename__ = "project_templates"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(Text)
    type = Column(String, nullable=False)
    language = Column(String, nullable=False)
    platforms = Column(JSON, default=[])  # List of supported platforms
    files = Column(JSON, default={})  # Template files and content
    dependencies = Column(JSON, default=[])
    config = Column(JSON, default={})
    icon = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class BuildConfiguration(Base):
    __tablename__ = "build_configurations"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("code_projects.id"), nullable=False)
    name = Column(String, nullable=False)
    command = Column(String, nullable=False)
    args = Column(JSON, default=[])
    environment = Column(JSON, default={})
    working_directory = Column(String)
    is_default = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    project = relationship("CodeProject")

class BuildExecution(Base):
    __tablename__ = "build_executions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("code_projects.id"), nullable=False)
    config_id = Column(String, ForeignKey("build_configurations.id"))
    status = Column(String, nullable=False)  # running, success, failed, cancelled
    exit_code = Column(Integer)
    output = Column(Text)
    error = Column(Text)
    build_time = Column(Integer)  # Build time in seconds
    started_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime)
    
    # Relationships
    project = relationship("CodeProject")
    configuration = relationship("BuildConfiguration")

class CollaborationSession(Base):
    __tablename__ = "collaboration_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("code_projects.id"), nullable=False)
    host_user_id = Column(String, ForeignKey("users.id"), nullable=False)
    session_name = Column(String)
    status = Column(String, default="active")  # active, paused, ended
    max_participants = Column(Integer, default=5)
    settings = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    ended_at = Column(DateTime)
    
    # Relationships
    project = relationship("CodeProject")
    participants = relationship("CollaborationParticipant", back_populates="session", cascade="all, delete-orphan")

class CollaborationParticipant(Base):
    __tablename__ = "collaboration_participants"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String, ForeignKey("collaboration_sessions.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    role = Column(String, default="collaborator")  # host, collaborator, viewer
    permissions = Column(JSON, default={"read": True, "write": False, "build": False})
    status = Column(String, default="active")  # active, away, disconnected
    joined_at = Column(DateTime, default=datetime.utcnow)
    last_active = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    session = relationship("CollaborationSession", back_populates="participants")

class VSCodeSync(Base):
    __tablename__ = "vscode_sync"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    vscode_path = Column(String)
    extension_version = Column(String)
    sync_settings = Column(JSON, default={})
    last_sync = Column(DateTime)
    status = Column(String, default="connected")  # connected, disconnected, error
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ProjectBackup(Base):
    __tablename__ = "project_backups"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("code_projects.id"), nullable=False)
    backup_type = Column(String, nullable=False)  # auto, manual, sync
    backup_path = Column(String, nullable=False)
    size_bytes = Column(Integer)
    checksum = Column(String)
    metadata = Column(JSON, default={})
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    project = relationship("CodeProject")

class CodeSnippet(Base):
    __tablename__ = "code_snippets"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    description = Column(Text)
    language = Column(String, nullable=False)
    code = Column(Text, nullable=False)
    tags = Column(JSON, default=[])
    is_public = Column(Boolean, default=False)
    usage_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ProjectAnalytics(Base):
    __tablename__ = "project_analytics"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("code_projects.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    metric_type = Column(String, nullable=False)  # build_time, lines_of_code, commits, etc.
    metric_value = Column(JSON)
    timestamp = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    project = relationship("CodeProject")

# Helper functions for model operations
def create_default_templates():
    """Create default project templates"""
    templates = [
        ProjectTemplate(
            id="flutter_app",
            name="Flutter Application",
            description="Cross-platform mobile app with Flutter",
            type="flutter",
            language="dart",
            platforms=["android", "ios", "web", "desktop"],
            dependencies=["flutter"],
            config={
                "flutter": {"version": "stable"},
                "platforms": ["android", "ios"]
            },
            files={
                "lib/main.dart": """import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('You have pushed the button this many times:'),
            Text('$_counter', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}""",
                "pubspec.yaml": """name: my_flutter_app
description: A new Flutter project created with Buddy Code Editor.
version: 1.0.0+1

environment:
  sdk: ">=2.17.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true"""
            }
        ),
        ProjectTemplate(
            id="python_app",
            name="Python Application",
            description="Python application with modern tooling",
            type="python",
            language="python",
            platforms=["desktop"],
            dependencies=["requests", "flask"],
            config={
                "python": {"version": "3.9+"},
                "requirements": "requirements.txt"
            },
            files={
                "main.py": '''#!/usr/bin/env python3
"""
Main module for the application.
Created with Buddy Code Editor.
"""

def main():
    """Main function."""
    print("Hello from Buddy Code Editor!")
    print("Your Python application is ready!")

if __name__ == "__main__":
    main()''',
                "requirements.txt": "requests>=2.28.0\nflask>=2.2.0",
                "README.md": "# My Python Project\n\nCreated with Buddy Code Editor"
            }
        ),
        ProjectTemplate(
            id="node_app",
            name="Node.js Application",
            description="Modern Node.js application",
            type="nodejs",
            language="javascript",
            platforms=["web", "desktop"],
            dependencies=["express", "nodemon"],
            config={
                "node": {"version": "16+"},
                "package": "package.json"
            },
            files={
                "index.js": '''const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello from Buddy Code Editor!');
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});''',
                "package.json": '''{
  "name": "my-node-app",
  "version": "1.0.0",
  "description": "Node.js application created with Buddy Code Editor",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.0",
    "jest": "^28.0.0"
  }
}'''
            }
        )
    ]
    return templates
