import * as vscode from 'vscode';
import * as chokidar from 'chokidar';
import * as path from 'path';
import { BuddySyncService, FileChange } from './buddySyncService';

export class FileWatcher {
  private watcher: chokidar.FSWatcher | null = null;
  private buddySyncService: BuddySyncService;
  private workspacePath: string = '';

  constructor(buddySyncService: BuddySyncService) {
    this.buddySyncService = buddySyncService;
  }

  startWatching(): void {
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

  stopWatching(): void {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
      console.log('Stopped watching workspace');
    }
  }

  private async handleFileAdd(filePath: string): Promise<void> {
    try {
      const content = await this.readFileContent(filePath);
      const relativePath = path.relative(this.workspacePath, filePath);

      const change: FileChange = {
        path: relativePath,
        content: content,
        action: 'create',
        timestamp: new Date()
      };

      this.buddySyncService.addPendingChange(change);
      console.log('File added:', relativePath);
    } catch (error) {
      console.error('Error handling file add:', error);
    }
  }

  private async handleFileChange(filePath: string): Promise<void> {
    try {
      const content = await this.readFileContent(filePath);
      const relativePath = path.relative(this.workspacePath, filePath);

      const change: FileChange = {
        path: relativePath,
        content: content,
        action: 'update',
        timestamp: new Date()
      };

      this.buddySyncService.addPendingChange(change);
      console.log('File changed:', relativePath);
    } catch (error) {
      console.error('Error handling file change:', error);
    }
  }

  private handleFileDelete(filePath: string): void {
    try {
      const relativePath = path.relative(this.workspacePath, filePath);

      const change: FileChange = {
        path: relativePath,
        content: '',
        action: 'delete',
        timestamp: new Date()
      };

      this.buddySyncService.addPendingChange(change);
      console.log('File deleted:', relativePath);
    } catch (error) {
      console.error('Error handling file delete:', error);
    }
  }

  private async readFileContent(filePath: string): Promise<string> {
    const uri = vscode.Uri.file(filePath);
    const document = await vscode.workspace.openTextDocument(uri);
    return document.getText();
  }

  dispose(): void {
    this.stopWatching();
  }
}