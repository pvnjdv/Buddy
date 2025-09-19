import * as vscode from 'vscode';
import axios, { AxiosInstance } from 'axios';
// WebSocket is available globally in VS Code extension context
declare const WebSocket: any;
import * as fs from 'fs';
import * as path from 'path';

export interface BuddyProject {
  id: string;
  name: string;
  description: string;
  repositoryUrl?: string;
  localPath?: string;
  lastModified: Date;
}

export interface FileChange {
  path: string;
  content: string;
  action: 'create' | 'update' | 'delete';
  timestamp: Date;
}

export class BuddySyncService {
  private httpClient: AxiosInstance;
  private wsClient: any = null;
  private isConnectedFlag = false;
  private currentProject: BuddyProject | null = null;
  private pendingChanges: Map<string, FileChange> = new Map();

  constructor(private context: vscode.ExtensionContext) {
    this.httpClient = axios.create({
      timeout: 10000,
    });
  }

  async connect(serverUrl: string, apiKey: string): Promise<void> {
    try {
      this.httpClient.defaults.baseURL = serverUrl;
      this.httpClient.defaults.headers.common['Authorization'] = `Bearer ${apiKey}`;

      // Test connection
      const response = await this.httpClient.get('/buddy/status');
      if (response.status !== 200) {
        throw new Error('Server not responding');
      }

      // Establish WebSocket connection for real-time sync
      await this.connectWebSocket(serverUrl, apiKey);

      this.isConnectedFlag = true;
    } catch (error) {
      this.isConnectedFlag = false;
      throw error;
    }
  }

  private async connectWebSocket(serverUrl: string, apiKey: string): Promise<void> {
    const wsUrl = serverUrl.replace(/^http/, 'ws') + '/ws/sync?token=' + encodeURIComponent(apiKey);
    this.wsClient = new WebSocket(wsUrl);

    return new Promise((resolve, reject) => {
      if (!this.wsClient) return reject(new Error('WebSocket client not initialized'));

      this.wsClient.onopen = () => {
        console.log('WebSocket connected to Buddy');
        resolve();
      };

      this.wsClient.onmessage = (event: any) => {
        try {
          const message = JSON.parse(event.data);
          this.handleWebSocketMessage(message);
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };

      this.wsClient.onerror = (error: any) => {
        console.error('WebSocket error:', error);
        reject(new Error('WebSocket connection failed'));
      };

      this.wsClient.onclose = () => {
        console.log('WebSocket disconnected from Buddy');
        this.isConnectedFlag = false;
      };
    });
  }

  private handleWebSocketMessage(message: any): void {
    switch (message.type) {
      case 'file_changed':
        this.handleRemoteFileChange(message.data);
        break;
      case 'project_updated':
        this.handleProjectUpdate(message.data);
        break;
      case 'sync_request':
        this.handleSyncRequest();
        break;
    }
  }

  private handleRemoteFileChange(data: any): void {
    const change: FileChange = {
      path: data.path,
      content: data.content,
      action: data.action,
      timestamp: new Date(data.timestamp)
    };

    // Apply change to local file
    this.applyFileChange(change);
  }

  private handleProjectUpdate(data: any): void {
    // Update project information
    if (this.currentProject && this.currentProject.id === data.id) {
      this.currentProject = { ...this.currentProject, ...data };
    }
  }

  private async handleSyncRequest(): Promise<void> {
    // Send pending changes to server
    await this.sync();
  }

  async disconnect(): Promise<void> {
    if (this.wsClient) {
      this.wsClient.close();
      this.wsClient = null;
    }
    this.isConnectedFlag = false;
  }

  isConnected(): boolean {
    return this.isConnectedFlag;
  }

  async getProjects(): Promise<BuddyProject[]> {
    try {
      const response = await this.httpClient.get('/api/projects');
      return response.data.map((p: any) => ({
        id: p.id,
        name: p.title || p.name,
        description: p.description || '',
        repositoryUrl: p.repository_url,
        localPath: p.local_path,
        lastModified: new Date(p.updated_at || p.lastModified)
      }));
    } catch (error) {
      throw new Error(`Failed to fetch projects: ${error}`);
    }
  }

  async openProject(project: BuddyProject): Promise<void> {
    this.currentProject = project;

    // If project has a local path, open it
    if (project.localPath) {
      const uri = vscode.Uri.file(project.localPath);
      await vscode.commands.executeCommand('vscode.openFolder', uri);
    } else if (project.repositoryUrl) {
      // Clone repository if not local
      await this.cloneRepository(project);
    }
  }

  private async cloneRepository(project: BuddyProject): Promise<void> {
    if (!project.repositoryUrl) return;

    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
      throw new Error('No workspace folder available');
    }

    const clonePath = path.join(workspaceFolder.uri.fsPath, project.name);

    // Use Git service to clone
    const { GitService } = require('./gitService');
    const gitService = new GitService();
    await gitService.clone(project.repositoryUrl, clonePath);

    // Update project local path
    project.localPath = clonePath;
    await this.updateProjectLocalPath(project);
  }

  private async updateProjectLocalPath(project: BuddyProject): Promise<void> {
    try {
      await this.httpClient.put(`/api/projects/${project.id}`, {
        local_path: project.localPath
      });
    } catch (error) {
      console.error('Failed to update project local path:', error);
    }
  }

  async sync(): Promise<void> {
    if (!this.currentProject) {
      throw new Error('No project selected');
    }

    // Send pending changes to server
    for (const [filePath, change] of this.pendingChanges) {
      try {
        await this.sendFileChange(change);
      } catch (error) {
        console.error(`Failed to sync ${filePath}:`, error);
      }
    }

    this.pendingChanges.clear();
  }

  async push(): Promise<void> {
    if (!this.currentProject) {
      throw new Error('No project selected');
    }

    const { GitService } = require('./gitService');
    const gitService = new GitService();

    try {
      // Commit changes
      await gitService.commit('Sync with Buddy');

      // Push to remote
      await gitService.push();

      vscode.window.showInformationMessage('Successfully pushed to repository');
    } catch (error) {
      throw new Error(`Push failed: ${error}`);
    }
  }

  async pull(): Promise<void> {
    if (!this.currentProject) {
      throw new Error('No project selected');
    }

    const { GitService } = require('./gitService');
    const gitService = new GitService();

    try {
      // Pull from remote
      await gitService.pull();

      vscode.window.showInformationMessage('Successfully pulled from repository');
    } catch (error) {
      throw new Error(`Pull failed: ${error}`);
    }
  }

  addPendingChange(change: FileChange): void {
    this.pendingChanges.set(change.path, change);

    // Auto-sync if enabled
    const config = vscode.workspace.getConfiguration('buddy');
    if (config.get('autoSync')) {
      // Debounce sync
      setTimeout(() => {
        if (this.pendingChanges.size > 0) {
          this.sync().catch(error => {
            console.error('Auto-sync failed:', error);
          });
        }
      }, config.get('syncInterval') as number || 5000);
    }
  }

  private async sendFileChange(change: FileChange): Promise<void> {
    const payload = {
      projectId: this.currentProject?.id,
      path: change.path,
      content: change.content,
      action: change.action,
      timestamp: change.timestamp.toISOString()
    };

    await this.httpClient.post('/api/sync/file-change', payload);

    // Send via WebSocket for real-time sync
    if (this.wsClient && this.wsClient.readyState === 1) { // WebSocket.OPEN = 1
      this.wsClient.send(JSON.stringify({
        type: 'file_change',
        data: payload
      }));
    }
  }

  private applyFileChange(change: FileChange): void {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) return;

    const fullPath = path.join(workspaceFolder.uri.fsPath, change.path);

    try {
      switch (change.action) {
        case 'create':
        case 'update':
          fs.writeFileSync(fullPath, change.content, 'utf8');
          break;
        case 'delete':
          if (fs.existsSync(fullPath)) {
            fs.unlinkSync(fullPath);
          }
          break;
      }
    } catch (error) {
      console.error(`Failed to apply file change to ${fullPath}:`, error);
    }
  }
}