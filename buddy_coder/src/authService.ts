import * as vscode from 'vscode';
import axios from 'axios';
import { ApiConfigManager } from './apiConfig';

export class AuthService {
    private accessToken: string | undefined;
    private refreshToken: string | undefined;
    private apiConfig: ApiConfigManager;
    private mobileNumber: string | undefined;

    constructor(context: vscode.ExtensionContext) {
        this.apiConfig = ApiConfigManager.getInstance(context);
        this.loadStoredCredentials();
    }

    private async loadStoredCredentials() {
        const config = vscode.workspace.getConfiguration('buddy-coder');
        this.mobileNumber = config.get('mobileNumber');
        
        // Try to load from global state if available
        const context = (global as any).buddyCoderContext;
        if (context) {
            this.accessToken = context.globalState.get('buddy.accessToken');
            this.refreshToken = context.globalState.get('buddy.refreshToken');
        }
    }

    private async storeCredentials(accessToken: string, refreshToken: string) {
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        
        const context = (global as any).buddyCoderContext;
        if (context) {
            await context.globalState.update('buddy.accessToken', accessToken);
            await context.globalState.update('buddy.refreshToken', refreshToken);
        }
    }

    async login(): Promise<boolean> {
        try {
            if (!this.mobileNumber) {
                const input = await vscode.window.showInputBox({
                    prompt: 'Enter your mobile number',
                    placeHolder: '9270416640 (test account) or your mobile number',
                    validateInput: (value) => {
                        if (!value || value.length < 10) {
                            return 'Please enter a valid mobile number';
                        }
                        return null;
                    }
                });
                
                if (!input) {
                    return false;
                }
                
                this.mobileNumber = input;
                
                // Store mobile number in settings
                const config = vscode.workspace.getConfiguration('buddy-coder');
                await config.update('mobileNumber', input, vscode.ConfigurationTarget.Global);
            }

            // Step 1: Send OTP using API config
            vscode.window.showInformationMessage(`Sending OTP to ${this.mobileNumber}...`);
            
            const otpEndpoint = this.apiConfig.getEndpoint('auth', 'requestOtp');
            const otpUrl = this.apiConfig.getFullUrl(otpEndpoint);
            
            console.log(`Sending OTP request to: ${otpUrl}`);
            
            const otpResponse = await axios.post(otpUrl, {
                mobile_number: this.mobileNumber
            }, {
                timeout: this.apiConfig.getSettings().timeout
            });

            if (otpResponse.status !== 200) {
                const errorMsg = otpResponse.data?.message || 'Unknown error';
                vscode.window.showErrorMessage(`Failed to send OTP: ${errorMsg}`);
                return false;
            }

            vscode.window.showInformationMessage('OTP sent successfully! Check terminal for test accounts.');

            // Step 2: Get OTP from user - ALWAYS ask for OTP
            let otpAttempts = 0;
            const maxAttempts = 3;
            
            while (otpAttempts < maxAttempts) {
                const otp = await vscode.window.showInputBox({
                    prompt: `Enter the OTP sent to ${this.mobileNumber} (Attempt ${otpAttempts + 1}/${maxAttempts})`,
                    placeHolder: '123456 (for test accounts) or your OTP',
                    password: false, // Don't hide OTP for easier debugging
                    validateInput: (value) => {
                        if (!value || value.length !== 6) {
                            return 'OTP must be 6 digits';
                        }
                        if (!/^\d{6}$/.test(value)) {
                            return 'OTP must contain only numbers';
                        }
                        return null;
                    }
                });

                if (!otp) {
                    vscode.window.showWarningMessage('Login cancelled');
                    return false;
                }

                // Step 3: Verify OTP and get tokens using API config
                try {
                    const verifyEndpoint = this.apiConfig.getEndpoint('auth', 'verifyOtp');
                    const verifyUrl = this.apiConfig.getFullUrl(verifyEndpoint);
                    
                    console.log(`Verifying OTP at: ${verifyUrl}`);
                    
                    const loginResponse = await axios.post(verifyUrl, {
                        mobile_number: this.mobileNumber,
                        otp: otp
                    }, {
                        timeout: this.apiConfig.getSettings().timeout
                    });

                    if (loginResponse.status === 200 && loginResponse.data.access_token) {
                        await this.storeCredentials(
                            loginResponse.data.access_token,
                            loginResponse.data.refresh_token
                        );
                        
                        vscode.window.showInformationMessage(
                            `✅ Successfully logged in to Buddy AI! (${this.apiConfig.getCurrentEnvironmentName()})`
                        );
                        return true;
                    } else {
                        throw new Error('Invalid response from server');
                    }
                } catch (otpError: any) {
                    otpAttempts++;
                    
                    let errorMessage = 'Invalid OTP';
                    if (otpError.response?.status === 400) {
                        errorMessage = otpError.response.data?.detail || 'Invalid OTP';
                    } else if (otpError.response?.status === 404) {
                        errorMessage = 'OTP verification endpoint not found';
                    } else if (otpError.message) {
                        errorMessage = otpError.message;
                    }
                    
                    if (otpAttempts >= maxAttempts) {
                        vscode.window.showErrorMessage(`❌ Login failed: ${errorMessage}. Please try again.`);
                        return false;
                    } else {
                        vscode.window.showWarningMessage(`❌ ${errorMessage}. Please try again. (${maxAttempts - otpAttempts} attempts remaining)`);
                        // Continue loop for retry
                    }
                }
            }
            
            return false;
        } catch (error: any) {
            let errorMessage = 'Login failed';
            if (error.response?.status === 404) {
                errorMessage = `Endpoint not found. Check if server is running at ${this.apiConfig.getServerUrl()}`;
            } else if (error.response?.data?.detail) {
                errorMessage = `Login failed: ${error.response.data.detail}`;
            } else if (error.code === 'ECONNREFUSED') {
                errorMessage = `Cannot connect to server at ${this.apiConfig.getServerUrl()}. Is the server running?`;
            } else if (error.message) {
                errorMessage = `Login failed: ${error.message}`;
            }
            
            vscode.window.showErrorMessage(`❌ ${errorMessage}`);
            console.error('Login error:', error);
            return false;
        }
    }

    async refreshAccessToken(): Promise<boolean> {
        try {
            if (!this.refreshToken) {
                return false;
            }

            const refreshEndpoint = this.apiConfig.getEndpoint('auth', 'refreshToken');
            const refreshUrl = this.apiConfig.getFullUrl(refreshEndpoint);

            const response = await axios.post(refreshUrl, {
                refresh_token: this.refreshToken
            });

            if (response.status === 200 && response.data.access_token) {
                await this.storeCredentials(
                    response.data.access_token,
                    this.refreshToken
                );
                return true;
            }
        } catch (error) {
            // Refresh token expired, need to login again
            this.accessToken = undefined;
            this.refreshToken = undefined;
        }
        return false;
    }

    async getValidToken(): Promise<string | undefined> {
        if (!this.accessToken) {
            const loginSuccess = await this.login();
            if (!loginSuccess) {
                return undefined;
            }
        }

        return this.accessToken;
    }

    async makeAuthenticatedRequest(endpoint: string, data: any): Promise<any> {
        try {
            const token = await this.getValidToken();
            if (!token) {
                throw new Error('Authentication required');
            }

            const url = this.apiConfig.getFullUrl(endpoint);
            const response = await axios.post(url, data, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            return response.data;
        } catch (error: any) {
            if (error.response?.status === 401) {
                // Token expired, try to refresh
                const refreshed = await this.refreshAccessToken();
                if (refreshed) {
                    // Retry with new token
                    const url = this.apiConfig.getFullUrl(endpoint);
                    const response = await axios.post(url, data, {
                        headers: {
                            'Authorization': `Bearer ${this.accessToken}`,
                            'Content-Type': 'application/json'
                        }
                    });
                    return response.data;
                } else {
                    // Force new login
                    const loginSuccess = await this.login();
                    if (loginSuccess) {
                        const url = this.apiConfig.getFullUrl(endpoint);
                        const response = await axios.post(url, data, {
                            headers: {
                                'Authorization': `Bearer ${this.accessToken}`,
                                'Content-Type': 'application/json'
                            }
                        });
                        return response.data;
                    }
                }
            }
            throw error;
        }
    }

    isAuthenticated(): boolean {
        return !!this.accessToken;
    }

    logout() {
        this.accessToken = undefined;
        this.refreshToken = undefined;
        
        const context = (global as any).buddyCoderContext;
        if (context) {
            context.globalState.update('buddy.accessToken', undefined);
            context.globalState.update('buddy.refreshToken', undefined);
        }
    }

    async switchEnvironment() {
        // Just call the API config switch method that toggles
        await this.apiConfig.switchEnvironment();
    }

    async sendChatMessage(message: string, mode: string = 'standard'): Promise<{ response: string; success: boolean }> {
        try {
            const token = await this.getValidToken();
            if (!token) {
                throw new Error('Not authenticated. Please login first.');
            }

            const chatEndpoint = this.apiConfig.getEndpoint('chat', 'vscode');
            const chatUrl = this.apiConfig.getFullUrl(chatEndpoint);

            console.log(`Sending chat message to: ${chatUrl} with mode: ${mode}`);

            const response = await axios.post(chatUrl, {
                message: message,
                sub_mode: mode,
                context: {
                    source: 'vscode',
                    mode: mode,
                    timestamp: new Date().toISOString()
                }
            }, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                timeout: this.apiConfig.getSettings().timeout
            });

            if (response.status === 200) {
                return {
                    response: response.data.response || response.data.content || 'No response received',
                    success: true
                };
            } else {
                throw new Error(`Server returned ${response.status}: ${response.statusText}`);
            }
        } catch (error: any) {
            console.error('Chat message error:', error);
            
            let errorMessage = 'Failed to send message';
            if (error.response?.status === 401) {
                errorMessage = 'Authentication expired. Please login again.';
                this.logout();
            } else if (error.response?.status === 404) {
                errorMessage = `Chat endpoint not found. Check server at ${this.apiConfig.getServerUrl()}`;
            } else if (error.code === 'ECONNREFUSED') {
                errorMessage = `Cannot connect to server at ${this.apiConfig.getServerUrl()}`;
            } else if (error.message) {
                errorMessage = error.message;
            }

            return {
                response: errorMessage,
                success: false
            };
        }
    }
}