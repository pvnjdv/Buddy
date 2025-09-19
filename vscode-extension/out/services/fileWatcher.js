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
Object.defineProperty(exports, "__esModule", { value: true });
exports.FileWatcher = void 0;
const vscode = __importStar(require("vscode"));
const chokidar = __importStar(require("chokidar"));
const path = __importStar(require("path"));
class FileWatcher {
    constructor(buddySyncService) {
        this.watcher = null;
        this.workspacePath = '';
        this.buddySyncService = buddySyncService;
    }
    startWatching() {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            vscode.window.showErrorMessage('No workspace folder to watch');
            return;
        }
        this.workspacePath = workspaceFolder.uri.fsPath;
        // Stop existing watcher
        this.stopWatching();
        // Create new watcher
        this.watcher = chokidar.watch(this.workspacePath, {
            ignored: [
                '**/node_modules/**',
                '**/.git/**',
                '**/build/**',
                '**/dist/**',
                '**/*.log',
                '**/.DS_Store'
            ],
            persistent: true,
            ignoreInitial: true,
            awaitWriteFinish: {
                stabilityThreshold: 100,
                pollInterval: 50
            }
        });
        this.watcher.on('add', (filePath) => this.handleFileAdd(filePath));
        this.watcher.on('change', (filePath) => this.handleFileChange(filePath));
        this.watcher.on('unlink', (filePath) => this.handleFileDelete(filePath));
        console.log('Started watching workspace:', this.workspacePath);
    }
    stopWatching() {
        if (this.watcher) {
            this.watcher.close();
            this.watcher = null;
            console.log('Stopped watching workspace');
        }
    }
    async handleFileAdd(filePath) {
        try {
            const content = await this.readFileContent(filePath);
            const relativePath = path.relative(this.workspacePath, filePath);
            const change = {
                path: relativePath,
                content: content,
                action: 'create',
                timestamp: new Date()
            };
            this.buddySyncService.addPendingChange(change);
            console.log('File added:', relativePath);
        }
        catch (error) {
            console.error('Error handling file add:', error);
        }
    }
    async handleFileChange(filePath) {
        try {
            const content = await this.readFileContent(filePath);
            const relativePath = path.relative(this.workspacePath, filePath);
            const change = {
                path: relativePath,
                content: content,
                action: 'update',
                timestamp: new Date()
            };
            this.buddySyncService.addPendingChange(change);
            console.log('File changed:', relativePath);
        }
        catch (error) {
            console.error('Error handling file change:', error);
        }
    }
    handleFileDelete(filePath) {
        try {
            const relativePath = path.relative(this.workspacePath, filePath);
            const change = {
                path: relativePath,
                content: '',
                action: 'delete',
                timestamp: new Date()
            };
            this.buddySyncService.addPendingChange(change);
            console.log('File deleted:', relativePath);
        }
        catch (error) {
            console.error('Error handling file delete:', error);
        }
    }
    async readFileContent(filePath) {
        const uri = vscode.Uri.file(filePath);
        const document = await vscode.workspace.openTextDocument(uri);
        return document.getText();
    }
    dispose() {
        this.stopWatching();
    }
}
exports.FileWatcher = FileWatcher;
//# sourceMappingURL=fileWatcher.js.map