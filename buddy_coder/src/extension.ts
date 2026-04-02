import * as vscode from 'vscode';
import { ChatProvider } from './chatProvider';
import { AuthService } from './authService';
import { ApiConfigManager } from './apiConfig';

export function activate(context: vscode.ExtensionContext) {
    // Store context globally for access from auth service
    (global as any).buddyCoderContext = context;
    
    // Initialize services
    const apiConfig = ApiConfigManager.getInstance(context);
    const authService = new AuthService(context);
    const provider = new ChatProvider(context, authService, apiConfig);
    
    // Register the webview provider
    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider(ChatProvider.viewType, provider)
    );
    
    // Register basic commands
    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.openChat', () => {
            vscode.commands.executeCommand('workbench.view.extension.buddy-coder');
        })
    );
    
    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.clearChat', () => {
            provider.clearChat();
        })
    );
    
    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.switchEnvironment', async () => {
            await authService.switchEnvironment();
        })
    );

    // Register AI-powered commands
    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.askAboutSelection', async () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor || editor.selection.isEmpty) {
                vscode.window.showWarningMessage('Please select some code first');
                return;
            }

            const selectedText = editor.document.getText(editor.selection);
            const fileName = vscode.workspace.asRelativePath(editor.document.fileName);
            const language = editor.document.languageId;

            const question = await vscode.window.showInputBox({
                prompt: `Ask Buddy AI about the selected ${language} code in ${fileName}`,
                placeHolder: 'What do you want to know about this code?'
            });

            if (question) {
                const enhancedPrompt = `I have selected this ${language} code from ${fileName}:

\`\`\`${language}
${selectedText}
\`\`\`

Question: ${question}`;
                
                // Open chat and send message
                vscode.commands.executeCommand('buddy-coder.openChat');
                provider.addMessage(enhancedPrompt, true);
                
                try {
                    const response = await authService.sendChatMessage(enhancedPrompt);
                    provider.addMessage(response.response, false);
                } catch (error) {
                    provider.addMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`, false);
                }
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.explainCode', async () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor || editor.selection.isEmpty) {
                vscode.window.showWarningMessage('Please select some code first');
                return;
            }

            const selectedText = editor.document.getText(editor.selection);
            const fileName = vscode.workspace.asRelativePath(editor.document.fileName);
            const language = editor.document.languageId;

            const prompt = `Please explain this ${language} code from ${fileName}:

\`\`\`${language}
${selectedText}
\`\`\`

Explain what this code does, how it works, and any important details.`;
            
            vscode.commands.executeCommand('buddy-coder.openChat');
            provider.addMessage(prompt, true);
            
            try {
                const response = await authService.sendChatMessage(prompt);
                provider.addMessage(response.response, false);
            } catch (error) {
                provider.addMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`, false);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.generateCode', async () => {
            const description = await vscode.window.showInputBox({
                prompt: 'Describe the code you want Buddy AI to generate',
                placeHolder: 'e.g., Create a function to calculate factorial, Build a REST API endpoint, etc.'
            });

            if (description) {
                const prompt = `Generate code for: ${description}

Please provide a complete, working solution with explanations.`;
                
                vscode.commands.executeCommand('buddy-coder.openChat');
                provider.addMessage(prompt, true);
                
                try {
                    const response = await authService.sendChatMessage(prompt);
                    provider.addMessage(response.response, false);
                } catch (error) {
                    provider.addMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`, false);
                }
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.reviewCode', async () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor || editor.selection.isEmpty) {
                vscode.window.showWarningMessage('Please select some code first');
                return;
            }

            const selectedText = editor.document.getText(editor.selection);
            const fileName = vscode.workspace.asRelativePath(editor.document.fileName);
            const language = editor.document.languageId;

            const prompt = `Please review this ${language} code from ${fileName}:

\`\`\`${language}
${selectedText}
\`\`\`

Provide feedback on:
- Code quality and best practices
- Potential bugs or issues
- Performance improvements
- Security considerations
- Suggestions for improvement`;
            
            vscode.commands.executeCommand('buddy-coder.openChat');
            provider.addMessage(prompt, true);
            
            try {
                const response = await authService.sendChatMessage(prompt);
                provider.addMessage(response.response, false);
            } catch (error) {
                provider.addMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`, false);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.refactorCode', async () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor || editor.selection.isEmpty) {
                vscode.window.showWarningMessage('Please select some code first');
                return;
            }

            const selectedText = editor.document.getText(editor.selection);
            const fileName = vscode.workspace.asRelativePath(editor.document.fileName);
            const language = editor.document.languageId;

            const refactorType = await vscode.window.showQuickPick([
                'Improve readability',
                'Optimize performance', 
                'Follow best practices',
                'Reduce complexity',
                'Add error handling',
                'Custom refactoring'
            ], {
                placeHolder: 'What kind of refactoring do you want?'
            });

            if (refactorType) {
                let prompt = `Please refactor this ${language} code from ${fileName}:

\`\`\`${language}
${selectedText}
\`\`\`

`;
                
                if (refactorType === 'Custom refactoring') {
                    const customRequest = await vscode.window.showInputBox({
                        prompt: 'Describe the specific refactoring you want',
                        placeHolder: 'e.g., Extract functions, use design patterns, etc.'
                    });
                    if (!customRequest) return;
                    prompt += `Refactoring goal: ${customRequest}`;
                } else {
                    prompt += `Refactoring goal: ${refactorType}`;
                }
                
                vscode.commands.executeCommand('buddy-coder.openChat');
                provider.addMessage(prompt, true);
                
                try {
                    const response = await authService.sendChatMessage(prompt);
                    provider.addMessage(response.response, false);
                } catch (error) {
                    provider.addMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`, false);
                }
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('buddy-coder.generateFlow', async () => {
            const projectDescription = await vscode.window.showInputBox({
                prompt: 'Describe your project to generate a development flow',
                placeHolder: 'e.g., Build a todo app with React and Node.js'
            });

            if (projectDescription) {
                const prompt = `Generate a detailed project development flow for: ${projectDescription}

Include:
- Planning and requirements
- Technology stack recommendations
- Development phases and milestones
- Timeline estimates
- Best practices and considerations`;
                
                vscode.commands.executeCommand('buddy-coder.openChat');
                provider.addMessage(prompt, true);
                
                try {
                    const response = await authService.sendChatMessage(prompt);
                    provider.addMessage(response.response, false);
                } catch (error) {
                    provider.addMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`, false);
                }
            }
        })
    );
    
    // Debug info
    console.log('✅ Buddy AI extension is now active!');
    apiConfig.printConfig();
    vscode.window.showInformationMessage('🤖 Buddy AI is ready! Use Ctrl+Shift+B to open chat.');
}

export function deactivate() {
    console.log('Buddy AI extension is now deactivated!');
}
