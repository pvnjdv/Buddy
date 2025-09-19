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
exports.deactivate = exports.activate = void 0;
const vscode = __importStar(require("vscode"));
const buddySyncService_1 = require("./services/buddySyncService");
const fileWatcher_1 = require("./services/fileWatcher");
let buddySyncService;
let fileWatcher;
let statusBarItem;
function activate(context) {
    console.log('Buddy Code Editor Sync extension is now active!');
    // Initialize services
    buddySyncService = new buddySyncService_1.BuddySyncService(context);
    fileWatcher = new fileWatcher_1.FileWatcher(buddySyncService);
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
    context.subscriptions.push(connectCommand, syncCommand, pushCommand, pullCommand, openProjectCommand, onDidChangeConfiguration, onDidChangeWorkspaceFolders, statusBarItem);
    // Auto-connect if configured
    const config = vscode.workspace.getConfiguration('buddy');
    if (config.get('apiKey')) {
        connectToBuddy();
    }
}
exports.activate = activate;
function deactivate() {
    if (fileWatcher) {
        fileWatcher.dispose();
    }
    if (statusBarItem) {
        statusBarItem.dispose();
    }
}
exports.deactivate = deactivate;
async function connectToBuddy() {
    try {
        const config = vscode.workspace.getConfiguration('buddy');
        const serverUrl = config.get('serverUrl');
        const apiKey = config.get('apiKey');
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
    }
    catch (error) {
        vscode.window.showErrorMessage(`Failed to connect to Buddy: ${error}`);
    }
}
async function syncWithBuddy() {
    try {
        await buddySyncService.sync();
        vscode.window.showInformationMessage('Synced with Buddy successfully!');
    }
    catch (error) {
        vscode.window.showErrorMessage(`Sync failed: ${error}`);
    }
}
async function pushToBuddy() {
    try {
        await buddySyncService.push();
        vscode.window.showInformationMessage('Pushed to Buddy successfully!');
    }
    catch (error) {
        vscode.window.showErrorMessage(`Push failed: ${error}`);
    }
}
async function pullFromBuddy() {
    try {
        await buddySyncService.pull();
        vscode.window.showInformationMessage('Pulled from Buddy successfully!');
    }
    catch (error) {
        vscode.window.showErrorMessage(`Pull failed: ${error}`);
    }
}
async function openBuddyProject() {
    try {
        const projects = await buddySyncService.getProjects();
        const selectedProject = await vscode.window.showQuickPick(projects.map((p) => ({ label: p.name, description: p.description, project: p })), { placeHolder: 'Select a Buddy project to open' });
        if (selectedProject) {
            await buddySyncService.openProject(selectedProject.project);
            vscode.window.showInformationMessage(`Opened project: ${selectedProject.label}`);
        }
    }
    catch (error) {
        vscode.window.showErrorMessage(`Failed to open project: ${error}`);
    }
}
function handleConfigurationChange(event) {
    if (event.affectsConfiguration('buddy')) {
        updateStatusBar();
    }
}
function handleWorkspaceChange(_event) {
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
    }
    else {
        statusBarItem.text = '$(plug) Connect Buddy';
        statusBarItem.tooltip = 'Not connected to Buddy - Click to connect';
        statusBarItem.command = 'buddy.connect';
        statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    }
    statusBarItem.show();
}
//# sourceMappingURL=extension.js.map