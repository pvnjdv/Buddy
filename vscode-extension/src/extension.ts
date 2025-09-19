import * as vscode from 'vscode';
import { BuddySyncService } from './services/buddySyncService';
import { FileWatcher } from './services/fileWatcher';

let buddySyncService: BuddySyncService;
let fileWatcher: FileWatcher;
let statusBarItem: vscode.StatusBarItem;

export function activate(context: vscode.ExtensionContext) {
  console.log('Buddy Code Editor Sync extension is now active!');

  // Initialize services
  buddySyncService = new BuddySyncService(context);
  fileWatcher = new FileWatcher(buddySyncService);

  // Create status bar item
  statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
  statusBarItem.command = 'buddy.connect';
  updateStatusBar();

  // Register commands
  const connectCommand = vscode.commands.registerCommand('buddy.connect', connectToBuddy);
  const syncCommand = vscode.commands.registerCommand('buddy.sync', syncWithBuddy);
  const pushCommand = vscode.commands.registerCommand('buddy.push', pushToBuddy);
  const pullCommand = vscode.commands.registerCommand('buddy.pull', pullFromBuddy);
  const openProjectCommand = vscode.commands.registerCommand('buddy.openProject', openBuddyProject);

  // Register event listeners
  const onDidChangeConfiguration = vscode.workspace.onDidChangeConfiguration(handleConfigurationChange);
  const onDidChangeWorkspaceFolders = vscode.workspace.onDidChangeWorkspaceFolders(handleWorkspaceChange);

  context.subscriptions.push(
    connectCommand,
    syncCommand,
    pushCommand,
    pullCommand,
    openProjectCommand,
    onDidChangeConfiguration,
    onDidChangeWorkspaceFolders,
    statusBarItem
  );

  // Auto-connect if configured
  const config = vscode.workspace.getConfiguration('buddy');
  if (config.get('apiKey')) {
    connectToBuddy();
  }
}

export function deactivate() {
  if (fileWatcher) {
    fileWatcher.dispose();
  }
  if (statusBarItem) {
    statusBarItem.dispose();
  }
}

async function connectToBuddy(): Promise<void> {
  try {
    const config = vscode.workspace.getConfiguration('buddy');
    const serverUrl = config.get('serverUrl') as string;
    const apiKey = config.get('apiKey') as string;

    if (!apiKey) {
      const input = await vscode.window.showInputBox({
        prompt: 'Enter your Buddy API key',
        placeHolder: 'Your Buddy API key'
      });

      if (!input) {
        return;
      }

      await config.update('apiKey', input, vscode.ConfigurationTarget.Global);
    }

    await buddySyncService.connect(serverUrl, apiKey);
    updateStatusBar();

    vscode.window.showInformationMessage('Connected to Buddy successfully!');

    // Start file watching if auto-sync is enabled
    if (config.get('autoSync')) {
      fileWatcher.startWatching();
    }

  } catch (error) {
    vscode.window.showErrorMessage(`Failed to connect to Buddy: ${error}`);
  }
}

async function syncWithBuddy(): Promise<void> {
  try {
    await buddySyncService.sync();
    vscode.window.showInformationMessage('Synced with Buddy successfully!');
  } catch (error) {
    vscode.window.showErrorMessage(`Sync failed: ${error}`);
  }
}

async function pushToBuddy(): Promise<void> {
  try {
    await buddySyncService.push();
    vscode.window.showInformationMessage('Pushed to Buddy successfully!');
  } catch (error) {
    vscode.window.showErrorMessage(`Push failed: ${error}`);
  }
}

async function pullFromBuddy(): Promise<void> {
  try {
    await buddySyncService.pull();
    vscode.window.showInformationMessage('Pulled from Buddy successfully!');
  } catch (error) {
    vscode.window.showErrorMessage(`Pull failed: ${error}`);
  }
}

async function openBuddyProject(): Promise<void> {
  try {
    const projects = await buddySyncService.getProjects();

    const selectedProject = await vscode.window.showQuickPick(
      projects.map((p: any) => ({ label: p.name, description: p.description, project: p })),
      { placeHolder: 'Select a Buddy project to open' }
    ) as { label: string; description: string; project: any } | undefined;

    if (selectedProject) {
      await buddySyncService.openProject(selectedProject.project);
      vscode.window.showInformationMessage(`Opened project: ${selectedProject.label}`);
    }
  } catch (error) {
    vscode.window.showErrorMessage(`Failed to open project: ${error}`);
  }
}

function handleConfigurationChange(event: vscode.ConfigurationChangeEvent) {
  if (event.affectsConfiguration('buddy')) {
    updateStatusBar();
  }
}

function handleWorkspaceChange(_event: vscode.WorkspaceFoldersChangeEvent) {
  // Handle workspace changes if needed
  updateStatusBar();
}

function updateStatusBar() {
  // const config = vscode.workspace.getConfiguration('buddy');
  const isConnected = buddySyncService?.isConnected() ?? false;

  if (isConnected) {
    statusBarItem.text = '$(sync) Buddy';
    statusBarItem.tooltip = 'Connected to Buddy - Click to sync';
    statusBarItem.command = 'buddy.sync';
    statusBarItem.backgroundColor = undefined;
  } else {
    statusBarItem.text = '$(plug) Connect Buddy';
    statusBarItem.tooltip = 'Not connected to Buddy - Click to connect';
    statusBarItem.command = 'buddy.connect';
    statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
  }

  statusBarItem.show();
}