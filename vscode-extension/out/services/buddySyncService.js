"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BuddySyncService = void 0;
const vscode = __importStar(require("vscode"));
const axios_1 = __importDefault(require("axios"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
class BuddySyncService {
    constructor(context) {
        this.context = context;
        this.wsClient = null;
        this.isConnectedFlag = false;
        this.currentProject = null;
        this.pendingChanges = new Map();
        this.httpClient = axios_1.default.create({
            timeout: 10000,
        });
    }
    async connect(serverUrl, apiKey) {
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
        }
        catch (error) {
            this.isConnectedFlag = false;
            throw error;
        }
    }
    async connectWebSocket(serverUrl, apiKey) {
        const wsUrl = serverUrl.replace(/^http/, 'ws') + '/ws/sync?token=' + encodeURIComponent(apiKey);
        this.wsClient = new WebSocket(wsUrl);
        return new Promise((resolve, reject) => {
            if (!this.wsClient)
                return reject(new Error('WebSocket client not initialized'));
            this.wsClient.onopen = () => {
                console.log('WebSocket connected to Buddy');
                resolve();
            };
            this.wsClient.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    this.handleWebSocketMessage(message);
                }
                catch (error) {
                    console.error('Failed to parse WebSocket message:', error);
                }
            };
            this.wsClient.onerror = (error) => {
                console.error('WebSocket error:', error);
                reject(new Error('WebSocket connection failed'));
            };
            this.wsClient.onclose = () => {
                console.log('WebSocket disconnected from Buddy');
                this.isConnectedFlag = false;
            };
        });
    }
    handleWebSocketMessage(message) {
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
    handleRemoteFileChange(data) {
        const change = {
            path: data.path,
            content: data.content,
            action: data.action,
            timestamp: new Date(data.timestamp)
        };
        // Apply change to local file
        this.applyFileChange(change);
    }
    handleProjectUpdate(data) {
        // Update project information
        if (this.currentProject && this.currentProject.id === data.id) {
            this.currentProject = { ...this.currentProject, ...data };
        }
    }
    async handleSyncRequest() {
        // Send pending changes to server
        await this.sync();
    }
    async disconnect() {
        if (this.wsClient) {
            this.wsClient.close();
            this.wsClient = null;
        }
        this.isConnectedFlag = false;
    }
    isConnected() {
        return this.isConnectedFlag;
    }
    async getProjects() {
        try {
            const response = await this.httpClient.get('/api/projects');
            return response.data.map((p) => ({
                id: p.id,
                name: p.title || p.name,
                description: p.description || '',
                repositoryUrl: p.repository_url,
                localPath: p.local_path,
                lastModified: new Date(p.updated_at || p.lastModified)
            }));
        }
        catch (error) {
            throw new Error(`Failed to fetch projects: ${error}`);
        }
    }
    async openProject(project) {
        this.currentProject = project;
        // If project has a local path, open it
        if (project.localPath) {
            const uri = vscode.Uri.file(project.localPath);
            await vscode.commands.executeCommand('vscode.openFolder', uri);
        }
        else if (project.repositoryUrl) {
            // Clone repository if not local
            await this.cloneRepository(project);
        }
    }
    async cloneRepository(project) {
        if (!project.repositoryUrl)
            return;
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
    async updateProjectLocalPath(project) {
        try {
            await this.httpClient.put(`/api/projects/${project.id}`, {
                local_path: project.localPath
            });
        }
        catch (error) {
            console.error('Failed to update project local path:', error);
        }
    }
    async sync() {
        if (!this.currentProject) {
            throw new Error('No project selected');
        }
        // Send pending changes to server
        for (const [filePath, change] of this.pendingChanges) {
            try {
                await this.sendFileChange(change);
            }
            catch (error) {
                console.error(`Failed to sync ${filePath}:`, error);
            }
        }
        this.pendingChanges.clear();
    }
    async push() {
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
        }
        catch (error) {
            throw new Error(`Push failed: ${error}`);
        }
    }
    async pull() {
        if (!this.currentProject) {
            throw new Error('No project selected');
        }
        const { GitService } = require('./gitService');
        const gitService = new GitService();
        try {
            // Pull from remote
            await gitService.pull();
            vscode.window.showInformationMessage('Successfully pulled from repository');
        }
        catch (error) {
            throw new Error(`Pull failed: ${error}`);
        }
    }
    addPendingChange(change) {
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
            }, config.get('syncInterval') || 5000);
        }
    }
    async sendFileChange(change) {
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
    applyFileChange(change) {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder)
            return;
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
        }
        catch (error) {
            console.error(`Failed to apply file change to ${fullPath}:`, error);
        }
    }
}
exports.BuddySyncService = BuddySyncService;
//# sourceMappingURL=buddySyncService.js.map