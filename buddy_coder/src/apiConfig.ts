import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

interface ApiEndpoints {
    auth: {
        requestOtp: string;
        verifyOtp: string;
        refreshToken: string;
        logout: string;
    };
    chat: {
        vscode: string;
        buddy: string;
    };
}

interface ApiEnvironment {
    name: string;
    serverUrl: string;
    apiPrefix: string;
    description: string;
}

interface ApiConfig {
    useProduction: boolean;
    environments: {
        local: ApiEnvironment;
        production: ApiEnvironment;
    };
    endpoints: ApiEndpoints;
    settings: {
        timeout: number;
        retries: number;
        autoRefreshToken: boolean;
    };
}

export class ApiConfigManager {
    private static instance: ApiConfigManager;
    private config: ApiConfig;

    private constructor(private context: vscode.ExtensionContext) {
        this.config = this.loadConfig();
    }

    public static getInstance(context?: vscode.ExtensionContext): ApiConfigManager {
        if (!ApiConfigManager.instance) {
            if (!context) {
                throw new Error('Context required for first initialization');
            }
            ApiConfigManager.instance = new ApiConfigManager(context);
        }
        return ApiConfigManager.instance;
    }

    private loadConfig(): ApiConfig {
        try {
            const configPath = path.join(__dirname, 'apiConfig.json');
            const configData = fs.readFileSync(configPath, 'utf8');
            return JSON.parse(configData);
        } catch (error) {
            // Fallback config if file doesn't exist
            return {
                useProduction: false,
                environments: {
                    local: {
                        name: 'Local Development',
                        serverUrl: 'http://10.31.112.3:8000',
                        apiPrefix: '',
                        description: 'Local development server'
                    },
                    production: {
                        name: 'Production Server',
                        serverUrl: 'https://buddy-production-11a1.up.railway.app',
                        apiPrefix: '',
                        description: 'Production server on Railway'
                    }
                },
                endpoints: {
                    auth: {
                        requestOtp: '/auth/request-otp',
                        verifyOtp: '/auth/verify-otp',
                        refreshToken: '/auth/refresh-token',
                        logout: '/auth/logout'
                    },
                    chat: {
                        vscode: '/api/vscode/chat',
                        buddy: '/buddy/ask'
                    }
                },
                settings: {
                    timeout: 30000,
                    retries: 3,
                    autoRefreshToken: true
                }
            };
        }
    }

    public async switchEnvironment() {
        // Toggle between production and local like the Dart file
        this.config.useProduction = !this.config.useProduction;
        
        // Save to VS Code settings
        const vsconfig = vscode.workspace.getConfiguration('buddy-coder');
        await vsconfig.update('useProduction', this.config.useProduction, vscode.ConfigurationTarget.Global);
        
        const currentEnv = this.getCurrentEnvironmentName();
        vscode.window.showInformationMessage(
            `Switched to ${currentEnv} environment`
        );
    }

    public getServerUrl(): string {
        const env = this.config.useProduction ? this.config.environments.production : this.config.environments.local;
        return env.serverUrl;
    }

    public getFullUrl(endpoint: string): string {
        const serverUrl = this.getServerUrl();
        const env = this.config.useProduction ? this.config.environments.production : this.config.environments.local;
        const apiPrefix = env.apiPrefix || '';
        
        return `${serverUrl}${apiPrefix}${endpoint}`;
    }

    public getEndpoint(category: keyof ApiEndpoints, endpoint: string): string {
        const categoryEndpoints = this.config.endpoints[category];
        if (categoryEndpoints && (categoryEndpoints as any)[endpoint]) {
            return (categoryEndpoints as any)[endpoint];
        }
        return endpoint;
    }

    public getCurrentEnvironmentName(): string {
        const env = this.config.useProduction ? this.config.environments.production : this.config.environments.local;
        return env.name;
    }

    public isProduction(): boolean {
        return this.config.useProduction;
    }

    public getSettings() {
        return this.config.settings;
    }

    public printConfig() {
        console.log(`API Environment: ${this.config.useProduction ? 'Production' : 'Local'}`);
        console.log(`API Base URL: ${this.getServerUrl()}`);
    }
}