import * as vscode from 'vscode';
import { AuthService } from './authService';
import { ApiConfigManager } from './apiConfig';

interface ChatMessage {
    id: string;
    text: string;
    isUser: boolean;
    timestamp: Date;
    isTyping?: boolean;
}

export class ChatProvider implements vscode.WebviewViewProvider {
    public static readonly viewType = 'buddy-coder.chatView';
    private _view?: vscode.WebviewView;
    private _messages: ChatMessage[] = [];

    constructor(
        private readonly _extensionContext: vscode.ExtensionContext,
        private _authService: AuthService,
        private _apiConfig: ApiConfigManager
    ) {}

    public resolveWebviewView(
        webviewView: vscode.WebviewView,
        context: vscode.WebviewViewResolveContext,
        _token: vscode.CancellationToken,
    ) {
        this._view = webviewView;

        webviewView.webview.options = {
            enableScripts: true,
            localResourceRoots: [
                this._extensionContext.extensionUri
            ]
        };

        webviewView.webview.html = this._getHtmlForWebview();

        // Handle messages from webview
        webviewView.webview.onDidReceiveMessage(
            message => {
                switch (message.command) {
                    case 'sendMessage':
                        this._handleSendMessage(message.text, message.mode);
                        break;
                    case 'clearChat':
                        this.clearChat();
                        break;
                    case 'login':
                        this._handleLogin();
                        break;
                    case 'switchEnvironment':
                        this._handleSwitchEnvironment();
                        break;
                    case 'showHistory':
                        this._handleShowHistory();
                        break;
                    case 'exportChat':
                        this._handleExportChat();
                        break;
                    case 'searchMessages':
                        this._handleSearchMessages();
                        break;
                    case 'showMenu':
                        this._handleShowMenu();
                        break;
                    case 'voiceInput':
                        this._handleVoiceInput();
                        break;
                    case 'attachCode':
                        this._handleAttachCode();
                        break;
                    case 'showModeSelector':
                        this._handleShowModeSelector();
                        break;
                }
            },
            undefined,
            this._extensionContext.subscriptions
        );

        this._updateMessages();
    }

    private async _handleLogin() {
        console.log('ChatProvider: Starting login process');
        const success = await this._authService.login();
        console.log('ChatProvider: Login result:', success);
        if (success) {
            this._view?.webview.postMessage({
                command: 'loginSuccess'
            });
        } else {
            this._view?.webview.postMessage({
                command: 'loginFailed'
            });
        }
    }

    private async _handleSwitchEnvironment() {
        await this._authService.switchEnvironment();
        this._view?.webview.postMessage({
            command: 'environmentChanged',
            environment: this._apiConfig.getCurrentEnvironmentName()
        });
    }
    
    private async _handleShowHistory() {
        // Show command palette with history options
        vscode.commands.executeCommand('buddy-coder.showChatHistory');
    }
    
    private async _handleExportChat() {
        // Export current chat to file
        vscode.commands.executeCommand('buddy-coder.exportChat');
    }
    
    private async _handleSearchMessages() {
        // Show search input in VS Code
        const searchQuery = await vscode.window.showInputBox({
            prompt: 'Search messages...',
            placeHolder: 'Enter search terms'
        });
        
        if (searchQuery) {
            // Implement search functionality
            this._view?.webview.postMessage({
                command: 'searchResults',
                query: searchQuery,
                results: [] // Implement search logic
            });
        }
    }
    
    private async _handleShowMenu() {
        // Show context menu with options
        const options = [
            'Clear Chat',
            'Export as PDF',
            'Settings',
            'About Buddy AI'
        ];
        
        const selected = await vscode.window.showQuickPick(options, {
            placeHolder: 'Choose an action...'
        });
        
        switch (selected) {
            case 'Clear Chat':
                this.clearChat();
                break;
            case 'Export as PDF':
                this._handleExportChat();
                break;
            case 'Settings':
                vscode.commands.executeCommand('workbench.action.openSettings', '@ext:buddy-coder');
                break;
            case 'About Buddy AI':
                vscode.window.showInformationMessage('Buddy AI - Your intelligent coding assistant');
                break;
        }
    }
    
    private async _handleVoiceInput() {
        // Show notification that voice input is coming soon
        vscode.window.showInformationMessage('🎤 Voice input coming soon!');
    }
    
    private async _handleAttachCode() {
        // Get current editor selection and add to chat context
        const editor = vscode.window.activeTextEditor;
        if (editor) {
            const selection = editor.selection;
            const selectedText = editor.document.getText(selection);
            
            if (selectedText.trim()) {
                const fileName = editor.document.fileName;
                const language = editor.document.languageId;
                
                this._view?.webview.postMessage({
                    command: 'codeAttached',
                    code: selectedText,
                    fileName: fileName,
                    language: language
                });
            } else {
                vscode.window.showWarningMessage('Please select some code first');
            }
        } else {
            vscode.window.showWarningMessage('No active editor found');
        }
    }
    
    private async _handleShowModeSelector() {
        const modes = [
            { label: '🧠 Standard Mode', description: 'Balanced AI responses', value: 'standard' },
            { label: '❓ Ask Mode', description: 'Question-focused assistance', value: 'ask' },
            { label: '🤖 Agent Mode', description: 'Autonomous task execution', value: 'agent' },
            { label: '🧮 Reasoning Mode', description: 'Deep analytical thinking', value: 'reasoning' },
            { label: '🔬 Deep Think Mode', description: 'Comprehensive analysis', value: 'deepthink' }
        ];
        
        const selected = await vscode.window.showQuickPick(modes, {
            placeHolder: 'Select AI Mode...'
        });
        
        if (selected) {
            this._view?.webview.postMessage({
                command: 'modeChanged',
                mode: selected.value,
                modeName: selected.label.split(' ').slice(1).join(' ')
            });
        }
    }

    private async _handleSendMessage(text: string, mode?: string) {
        if (!text.trim()) {
            return;
        }
        
        const aiMode = mode || 'standard';

        // Add user message
        const userMessage: ChatMessage = {
            id: Date.now().toString(),
            text: text,
            isUser: true,
            timestamp: new Date()
        };

        this._messages.push(userMessage);
        this._updateMessages();

        // Show typing indicator
        const typingMessage: ChatMessage = {
            id: 'typing',
            text: '',
            isUser: false,
            timestamp: new Date(),
            isTyping: true
        };

        this._messages.push(typingMessage);
        this._updateMessages();

        try {
            const response = await this._authService.sendChatMessage(text, aiMode);
            
            // Remove typing indicator
            this._messages = this._messages.filter(msg => msg.id !== 'typing');

            // Add AI response
            const aiMessage: ChatMessage = {
                id: (Date.now() + 1).toString(),
                text: response.response,
                isUser: false,
                timestamp: new Date()
            };

            this._messages.push(aiMessage);
            this._updateMessages();

        } catch (error) {
            // Remove typing indicator
            this._messages = this._messages.filter(msg => msg.id !== 'typing');

            // Add error message
            const errorMessage: ChatMessage = {
                id: (Date.now() + 2).toString(),
                text: `Error: ${error instanceof Error ? error.message : 'Unknown error occurred'}`,
                isUser: false,
                timestamp: new Date()
            };

            this._messages.push(errorMessage);
            this._updateMessages();
        }
    }

    public clearChat() {
        this._messages = [];
        this._updateMessages();
    }

    public addMessage(text: string, isUser: boolean = false) {
        const message: ChatMessage = {
            id: Date.now().toString(),
            text: text,
            isUser: isUser,
            timestamp: new Date()
        };

        this._messages.push(message);
        this._updateMessages();
    }

    private _updateMessages() {
        if (this._view) {
            this._view.webview.postMessage({
                command: 'updateMessages',
                messages: this._messages,
                environment: this._apiConfig.getCurrentEnvironmentName()
            });
        }
    }

    private _getHtmlForWebview(): string {
        return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Buddy AI Assistant</title>
    <style>
        * {
            box-sizing: border-box;
        }
        body {
            padding: 0;
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            background: linear-gradient(135deg, #0D1B2A 0%, #1B263B 50%, #2D3748 100%);
            color: white;
            height: 100vh;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }
        
        /* Enhanced Header with Buddy Logo */
        .header {
            background: linear-gradient(90deg, rgba(26, 32, 44, 0.9) 0%, rgba(45, 55, 72, 0.9) 100%);
            padding: 12px 16px;
            border-bottom: 1px solid rgba(74, 85, 104, 0.3);
            box-shadow: 0 2px 20px rgba(0,0,0,0.3);
        }
        
        .header-content {
            display: flex;
            align-items: center;
            gap: 14px;
        }
        
        .buddy-logo {
            width: 44px;
            height: 44px;
            background: linear-gradient(135deg, #667EEA 0%, #764BA2 100%);
            border-radius: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4), 0 2px 8px rgba(118, 75, 162, 0.3);
            position: relative;
            overflow: hidden;
        }
        
        .buddy-logo::before {
            content: '';
            position: absolute;
            inset: 0;
            background: radial-gradient(circle at 30% 30%, rgba(255,255,255,0.3), transparent 60%);
        }
        
        .buddy-logo .icon {
            font-size: 24px;
            z-index: 1;
        }
        
        .header-info {
            flex: 1;
        }
        
        .header-title {
            font-size: 18px;
            font-weight: bold;
            margin: 0;
            letter-spacing: 0.5px;
        }
        
        .header-subtitle {
            font-size: 12px;
            opacity: 0.8;
            margin: 2px 0 0 0;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        
        .status-indicator {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #10B981;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.7; transform: scale(1.1); }
        }
        
        .header-actions {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .action-btn {
            width: 36px;
            height: 36px;
            border: none;
            border-radius: 8px;
            background: rgba(45, 55, 72, 0.8);
            color: white;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            font-size: 16px;
        }
        
        .action-btn:hover {
            background: rgba(102, 126, 234, 0.3);
            transform: scale(1.05);
        }
        
        .mode-badge {
            background: rgba(102, 126, 234, 0.2);
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 10px;
            margin-left: auto;
            border: 1px solid rgba(102, 126, 234, 0.4);
        }
        
        /* Feature Toolbar */
        .feature-toolbar {
            background: rgba(26, 32, 44, 0.9);
            padding: 12px 16px;
            border-bottom: 1px solid rgba(74, 85, 104, 0.2);
            display: flex;
            gap: 8px;
            overflow-x: auto;
            scrollbar-width: none;
        }
        
        .feature-toolbar::-webkit-scrollbar {
            display: none;
        }
        
        .feature-btn {
            flex-shrink: 0;
            padding: 8px 12px;
            border: none;
            border-radius: 20px;
            background: rgba(45, 55, 72, 0.6);
            color: white;
            cursor: pointer;
            font-size: 12px;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 6px;
            min-width: fit-content;
        }
        
        .feature-btn:hover, .feature-btn.active {
            background: linear-gradient(135deg, #667EEA 0%, #764BA2 100%);
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
        }
        
        .feature-btn .emoji {
            font-size: 14px;
        }
        
        /* Chat Container */
        .chat-container {
            flex: 1;
            display: flex;
            flex-direction: column;
            min-height: 0;
            position: relative;
        }
        
        .messages {
            flex: 1;
            overflow-y: auto;
            padding: 16px;
            display: flex;
            flex-direction: column;
            gap: 12px;
            scroll-behavior: smooth;
        }
        
        .messages::-webkit-scrollbar {
            width: 4px;
        }
        
        .messages::-webkit-scrollbar-track {
            background: rgba(45, 55, 72, 0.3);
        }
        
        .messages::-webkit-scrollbar-thumb {
            background: rgba(102, 126, 234, 0.5);
            border-radius: 2px;
        }
        
        /* Enhanced Empty State */
        .empty-state {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            text-align: center;
            padding: 40px 20px;
        }
        
        .empty-logo {
            width: 120px;
            height: 120px;
            background: linear-gradient(135deg, #667EEA, #764BA2);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 24px;
            font-size: 48px;
            box-shadow: 0 20px 40px rgba(102, 126, 234, 0.3);
            animation: float 3s ease-in-out infinite;
            position: relative;
        }
        
        .empty-logo::before {
            content: '';
            position: absolute;
            inset: -2px;
            background: linear-gradient(135deg, #667EEA, #764BA2, #667EEA);
            border-radius: 50%;
            z-index: -1;
            animation: rotate 4s linear infinite;
        }
        
        @keyframes float {
            0%, 100% { transform: translateY(0px); }
            50% { transform: translateY(-10px); }
        }
        
        @keyframes rotate {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
        
        .welcome-text {
            font-size: 28px;
            font-weight: bold;
            background: linear-gradient(135deg, #667EEA, #764BA2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 12px;
        }
        
        .welcome-subtitle {
            font-size: 16px;
            color: rgba(255, 255, 255, 0.7);
            line-height: 1.5;
            margin-bottom: 32px;
            max-width: 300px;
        }
        
        /* Message Bubbles */
        .message-bubble {
            display: flex;
            gap: 12px;
            max-width: 85%;
            animation: slideIn 0.3s ease-out;
        }
        
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .message-bubble.user {
            align-self: flex-end;
            flex-direction: row-reverse;
        }
        
        .message-avatar {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            flex-shrink: 0;
        }
        
        .user-avatar {
            background: linear-gradient(135deg, #667EEA, #10B981);
        }
        
        .buddy-avatar {
            background: linear-gradient(135deg, #764BA2, #667EEA);
        }
        
        .message-content {
            background: rgba(45, 55, 72, 0.8);
            padding: 12px 16px;
            border-radius: 18px;
            border: 1px solid rgba(74, 85, 104, 0.3);
            backdrop-filter: blur(10px);
        }
        
        .message-bubble.user .message-content {
            background: linear-gradient(135deg, #667EEA, #764BA2);
        }
        
        .message-text {
            margin: 0;
            line-height: 1.4;
            word-wrap: break-word;
        }
        
        .message-time {
            font-size: 11px;
            opacity: 0.6;
            margin-top: 4px;
        }
        
        /* Typing Indicator */
        .typing-indicator {
            display: flex;
            align-items: center;
            gap: 12px;
            max-width: 85%;
            margin-bottom: 12px;
        }
        
        .typing-dots {
            background: rgba(45, 55, 72, 0.8);
            padding: 12px 16px;
            border-radius: 18px;
            border: 1px solid rgba(74, 85, 104, 0.3);
            display: flex;
            gap: 4px;
            align-items: center;
        }
        
        .typing-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.6);
            animation: typingDot 1.5s ease-in-out infinite;
        }
        
        .typing-dot:nth-child(2) { animation-delay: 0.2s; }
        .typing-dot:nth-child(3) { animation-delay: 0.4s; }
        
        @keyframes typingDot {
            0%, 60%, 100% { opacity: 0.3; transform: scale(1); }
            30% { opacity: 1; transform: scale(1.2); }
        }
        
        /* Enhanced Input Area */
        .input-area {
            padding: 16px;
            background: linear-gradient(180deg, rgba(27, 38, 59, 0.3) 0%, rgba(27, 38, 59, 0.9) 100%);
            border-top: 1px solid rgba(74, 85, 104, 0.3);
            backdrop-filter: blur(20px);
        }
        
        .input-container {
            display: flex;
            gap: 8px;
            align-items: flex-end;
        }
        
        .input-wrapper {
            flex: 1;
            position: relative;
        }
        
        .message-input {
            width: 100%;
            background: rgba(45, 55, 72, 0.8);
            border: 2px solid rgba(74, 85, 104, 0.3);
            border-radius: 24px;
            padding: 14px 50px 14px 20px;
            color: white;
            font-size: 14px;
            resize: none;
            outline: none;
            transition: all 0.2s;
            max-height: 120px;
            min-height: 48px;
        }
        
        .message-input:focus {
            border-color: rgba(102, 126, 234, 0.6);
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .message-input::placeholder {
            color: rgba(255, 255, 255, 0.5);
        }
        
        .input-actions {
            position: absolute;
            right: 8px;
            top: 50%;
            transform: translateY(-50%);
            display: flex;
            gap: 4px;
        }
        
        .input-btn {
            width: 32px;
            height: 32px;
            border: none;
            border-radius: 50%;
            background: rgba(102, 126, 234, 0.2);
            color: white;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            font-size: 14px;
        }
        
        .input-btn:hover {
            background: rgba(102, 126, 234, 0.4);
            transform: scale(1.1);
        }
        
        .send-button {
            width: 48px;
            height: 48px;
            border: none;
            border-radius: 50%;
            background: linear-gradient(135deg, #667EEA 0%, #764BA2 100%);
            color: white;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            font-size: 20px;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
        }
        
        .send-button:hover {
            transform: scale(1.05);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
        }
        
        .send-button:disabled {
            background: rgba(45, 55, 72, 0.6);
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }
        
        /* Mode Selector */
        .mode-selector {
            width: 48px;
            height: 48px;
            border: none;
            border-radius: 50%;
            background: rgba(45, 55, 72, 0.8);
            border: 1px solid rgba(74, 85, 104, 0.4);
            color: white;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            font-size: 18px;
        }
        
        .mode-selector:hover {
            background: rgba(102, 126, 234, 0.3);
            transform: scale(1.05);
        }
        
        .auth-notice {
            background: linear-gradient(135deg, rgba(239, 68, 68, 0.1), rgba(245, 101, 101, 0.1));
            border: 1px solid rgba(239, 68, 68, 0.3);
            border-radius: 16px;
            padding: 24px;
            margin: 20px;
            text-align: center;
        }
        
        .login-button {
            background: linear-gradient(135deg, #10B981 0%, #667EEA 100%);
            border: none;
            border-radius: 12px;
            color: white;
            padding: 12px 24px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 16px;
            transition: all 0.2s;
        }
        
        .login-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(16, 185, 129, 0.3);
        }
    </style>
</head>
<body>
    <!-- Enhanced Header with Mobile App Features -->
    <div class="header">
        <div class="header-content">
            <div class="buddy-logo">
                <div class="icon">🤖</div>
            </div>
            <div class="header-info">
                <div class="header-title">Buddy AI</div>
                <div class="header-subtitle">
                    <div class="status-indicator"></div>
                    <span id="statusText">Your intelligent coding assistant</span>
                    <span class="mode-badge" id="modeBadge">Standard</span>
                </div>
            </div>
            <div class="header-actions">
                <button class="action-btn" id="newChatBtn" title="New Conversation">➕</button>
                <button class="action-btn" id="historyBtn" title="Chat History">📚</button>
                <button class="action-btn" id="exportBtn" title="Export Chat">📤</button>
                <button class="action-btn" id="searchBtn" title="Search Messages">🔍</button>
                <button class="action-btn" id="menuBtn" title="More Options">⋯</button>
            </div>
        </div>
    </div>
    
    <!-- Feature Toolbar with All Mobile App Features -->
    <div class="feature-toolbar" id="featureToolbar">
        <button class="feature-btn active" data-feature="chat">
            <span class="emoji">💬</span> Chat
        </button>
        <button class="feature-btn" data-feature="code-explain">
            <span class="emoji">🔍</span> Explain Code
        </button>
        <button class="feature-btn" data-feature="code-generate">
            <span class="emoji">⚡</span> Generate Code
        </button>
        <button class="feature-btn" data-feature="code-review">
            <span class="emoji">🔎</span> Review Code
        </button>
        <button class="feature-btn" data-feature="refactor">
            <span class="emoji">🛠️</span> Refactor
        </button>
        <button class="feature-btn" data-feature="debug">
            <span class="emoji">🐛</span> Debug
        </button>
        <button class="feature-btn" data-feature="flow">
            <span class="emoji">🎯</span> Create Flow
        </button>
        <button class="feature-btn" data-feature="docs">
            <span class="emoji">📖</span> Documentation
        </button>
        <button class="feature-btn" data-feature="optimize">
            <span class="emoji">⚡</span> Optimize
        </button>
        <button class="feature-btn" data-feature="test">
            <span class="emoji">🧪</span> Generate Tests
        </button>
    </div>
    
    <div class="chat-container">
        <div class="messages" id="messages">
            <div class="empty-state" id="emptyState">
                <div class="empty-logo">🤖</div>
                <div class="welcome-text">Hello! I'm Buddy</div>
                <div class="welcome-subtitle">Your intelligent AI assistant for coding, project management, and creative tasks</div>
                <div style="display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; max-width: 300px;">
                    <button class="feature-btn" onclick="insertSample('Explain this code')">
                        <span class="emoji">🔍</span> Explain Code
                    </button>
                    <button class="feature-btn" onclick="insertSample('Generate a calculator app')">
                        <span class="emoji">⚡</span> Generate App
                    </button>
                    <button class="feature-btn" onclick="insertSample('Review my code for bugs')">
                        <span class="emoji">🔎</span> Code Review
                    </button>
                    <button class="feature-btn" onclick="insertSample('Create a project flow for')">
                        <span class="emoji">🎯</span> Project Flow
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Enhanced Input Area with All Mobile Features -->
        <div class="input-area">
            <div class="input-container">
                <!-- AI Mode Selector -->
                <button class="mode-selector" id="modeSelector" title="AI Mode">🧠</button>
                
                <!-- Input with Actions -->
                <div class="input-wrapper">
                    <textarea id="messageInput" class="message-input" placeholder="💭 Ask Buddy anything..." rows="1"></textarea>
                    <div class="input-actions">
                        <button class="input-btn" id="voiceBtn" title="Voice Input">🎤</button>
                        <button class="input-btn" id="attachBtn" title="Attach Code">📎</button>
                    </div>
                </div>
                
                <!-- Send Button -->
                <button id="sendButton" class="send-button" disabled>
                    <span id="sendIcon">▶</span>
                </button>
            </div>
        </div>
    </div>

    <script>
        const vscode = acquireVsCodeApi();
        const messagesContainer = document.getElementById('messages');
        const messageInput = document.getElementById('messageInput');
        const sendButton = document.getElementById('sendButton');
        const emptyState = document.getElementById('emptyState');
        const modeBadge = document.getElementById('modeBadge');
        const statusText = document.getElementById('statusText');
        
        let currentMode = 'standard';
        let isTyping = false;
        
        // Enhanced feature system
        const features = {
            'chat': { name: 'General Chat', prompt: '' },
            'code-explain': { name: 'Explain Code', prompt: 'Explain this code: ' },
            'code-generate': { name: 'Generate Code', prompt: 'Generate code for: ' },
            'code-review': { name: 'Code Review', prompt: 'Review this code for bugs and improvements: ' },
            'refactor': { name: 'Refactor Code', prompt: 'Refactor this code to improve readability and performance: ' },
            'debug': { name: 'Debug Code', prompt: 'Debug this code and fix the issues: ' },
            'flow': { name: 'Create Flow', prompt: 'Create a project flow for: ' },
            'docs': { name: 'Documentation', prompt: 'Generate documentation for: ' },
            'optimize': { name: 'Optimize Code', prompt: 'Optimize this code for better performance: ' },
            'test': { name: 'Generate Tests', prompt: 'Generate unit tests for: ' }
        };
        
        // Event Listeners
        sendButton.addEventListener('click', sendMessage);
        messageInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });
        
        messageInput.addEventListener('input', function() {
            const isEmpty = this.value.trim() === '';
            sendButton.disabled = isEmpty || isTyping;
            sendButton.style.opacity = isEmpty || isTyping ? '0.5' : '1';
        });
        
        // Feature toolbar functionality
        document.querySelectorAll('.feature-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                if (this.dataset.feature) {
                    selectFeature(this.dataset.feature);
                }
            });
        });
        
        // Header action buttons
        document.getElementById('newChatBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'clearChat' });
        });
        
        document.getElementById('historyBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'showHistory' });
        });
        
        document.getElementById('exportBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'exportChat' });
        });
        
        document.getElementById('searchBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'searchMessages' });
        });
        
        document.getElementById('menuBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'showMenu' });
        });
        
        // Mode selector
        document.getElementById('modeSelector').addEventListener('click', () => {
            showModeSelector();
        });
        
        // Voice and attach buttons
        document.getElementById('voiceBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'voiceInput' });
        });
        
        document.getElementById('attachBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'attachCode' });
        });
        
        // Functions
        function selectFeature(featureId) {
            // Update active state
            document.querySelectorAll('.feature-btn').forEach(btn => {
                btn.classList.remove('active');
            });
            document.querySelector('[data-feature="' + featureId + '"]').classList.add('active');
            
            // Update input placeholder and add prompt prefix if needed
            const feature = features[featureId];
            if (feature) {
                if (feature.prompt) {
                    messageInput.placeholder = '💭 ' + feature.name + '...';
                    if (!messageInput.value.startsWith(feature.prompt)) {
                        messageInput.value = feature.prompt;
                        messageInput.focus();
                        messageInput.setSelectionRange(feature.prompt.length, feature.prompt.length);
                    }
                } else {
                    messageInput.placeholder = '💭 Ask Buddy anything...';
                }
            }
        }
        
        function insertSample(text) {
            messageInput.value = text;
            messageInput.focus();
            messageInput.dispatchEvent(new Event('input'));
        }
        
        function sendMessage() {
            const text = messageInput.value.trim();
            if (!text || isTyping) return;
            
            vscode.postMessage({ 
                command: 'sendMessage', 
                text: text,
                mode: currentMode 
            });
            messageInput.value = '';
            messageInput.dispatchEvent(new Event('input'));
        }
        
        function showModeSelector() {
            const modes = [
                { id: 'standard', name: 'Standard', icon: '🧠', desc: 'Balanced AI responses' },
                { id: 'ask', name: 'Ask Mode', icon: '❓', desc: 'Question-focused assistance' },
                { id: 'agent', name: 'Agent Mode', icon: '🤖', desc: 'Autonomous task execution' },
                { id: 'reasoning', name: 'Reasoning', icon: '🧮', desc: 'Deep analytical thinking' },
                { id: 'deepthink', name: 'Deep Think', icon: '🔬', desc: 'Comprehensive analysis' }
            ];
            
            vscode.postMessage({ 
                command: 'showModeSelector', 
                modes: modes,
                currentMode: currentMode 
            });
        }
        
        function addMessage(message, isUser = false, isTyping = false) {
            if (emptyState.style.display !== 'none') {
                emptyState.style.display = 'none';
            }
            
            const messageDiv = document.createElement('div');
            messageDiv.className = 'message-bubble ' + (isUser ? 'user' : '');
            
            const avatar = document.createElement('div');
            avatar.className = 'message-avatar ' + (isUser ? 'user-avatar' : 'buddy-avatar');
            avatar.textContent = isUser ? '👤' : '🤖';
            
            const content = document.createElement('div');
            content.className = 'message-content';
            
            if (isTyping) {
                content.innerHTML = '<div class="typing-dots"><div class="typing-dot"></div><div class="typing-dot"></div><div class="typing-dot"></div></div>';
            } else {
                const text = document.createElement('div');
                text.className = 'message-text';
                text.textContent = message;
                
                const time = document.createElement('div');
                time.className = 'message-time';
                time.textContent = new Date().toLocaleTimeString();
                
                content.appendChild(text);
                content.appendChild(time);
            }
            
            messageDiv.appendChild(avatar);
            messageDiv.appendChild(content);
            messagesContainer.appendChild(messageDiv);
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
            
            return messageDiv;
        }
        
        function showNotification(message, type = 'info') {
            const notification = document.createElement('div');
            notification.className = 'notification';
            notification.textContent = message;
            document.body.appendChild(notification);
            
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 3000);
        }
        
        function updateMode(mode, modeName) {
            currentMode = mode;
            modeBadge.textContent = modeName;
            showNotification('Switched to ' + modeName + ' mode');
        }
        
        function updateStatus(status) {
            statusText.textContent = status;
        }
        
        // Handle messages from extension
        window.addEventListener('message', event => {
            const message = event.data;
            
            switch (message.command) {
                case 'updateMessages':
                    if (message.messages && message.messages.length > 0) {
                        emptyState.style.display = 'none';
                        messagesContainer.innerHTML = '';
                        
                        message.messages.forEach(msg => {
                            addMessage(msg.text, msg.isUser, msg.isTyping);
                        });
                    } else {
                        emptyState.style.display = 'flex';
                    }
                    break;
                    
                case 'addMessage':
                    addMessage(message.text, message.isUser, message.isTyping);
                    break;
                    
                case 'startTyping':
                    isTyping = true;
                    const typingMsg = addMessage('', false, true);
                    sendButton.disabled = true;
                    break;
                    
                case 'stopTyping':
                    isTyping = false;
                    sendButton.disabled = messageInput.value.trim() === '';
                    // Remove typing indicator
                    const typingIndicators = document.querySelectorAll('.typing-dots');
                    typingIndicators.forEach(indicator => {
                        const bubble = indicator.closest('.message-bubble');
                        if (bubble) bubble.remove();
                    });
                    break;
                    
                case 'modeChanged':
                    updateMode(message.mode, message.modeName);
                    break;
                    
                case 'statusUpdate':
                    updateStatus(message.status);
                    break;
                    
                case 'showNotification':
                    showNotification(message.text, message.type);
                    break;
                    
                case 'loginSuccess':
                    updateStatus('Connected to Buddy AI');
                    showNotification('Successfully logged in!');
                    break;
                    
                case 'loginFailed':
                    updateStatus('Authentication required');
                    showNotification('Login failed. Please try again.', 'error');
                    break;
                    
                case 'environmentChanged':
                    showNotification('Environment: ' + message.environment);
                    break;
            }
        });
        
        // Initialize
        updateStatus('Ready to assist you');
    </script>
</body>
</html>
        `;
    }
}
