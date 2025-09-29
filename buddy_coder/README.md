# Buddy Coder - VS Code Extension

A VS Code extension that integrates with Buddy AI backend to provide intelligent coding assistance directly in your editor.

## ✨ Features

- **Chat with Buddy AI**: Interactive chat panel for coding assistance
- **Environment Switching**: Easy switching between local, staging, and production servers
- **Same Authentication**: Uses the same mobile number + OTP authentication as the main Buddy app  
- **VS Code Integration**: Seamlessly integrated into your VS Code workflow
- **Beautiful UI**: Matches the Buddy app's design with gradient themes

## 🚀 Quick Setup

### 1. Install Dependencies
```bash
cd buddy_coder
npm install
npm run compile
```

### 2. Run in Development
- Press `F5` in VS Code to launch Extension Development Host
- Or use `Ctrl+Shift+P` → "Debug: Start Debugging"

### 3. First Time Setup
1. Click the robot icon (🤖) in the Activity Bar
2. Click "Login with Mobile Number"
3. Enter your mobile number (use `9270416640` for test account)
4. Enter OTP `123456` for test accounts
5. Start chatting with Buddy AI!

## ⚙️ Configuration

The extension supports multiple environments through VS Code settings:

### Environment Settings
- **Local**: `http://localhost:8000` (default)
- **Production**: Your production server URL
- **Staging**: Your staging server URL

### Switch Environments
- Click the ⚙️ button in the chat interface
- Or use Command Palette: `Buddy: Switch API Environment`
- Or go to VS Code Settings → Extensions → Buddy Coder

### Available Settings
```json
{
  "buddy-coder.environment": "local",           // API environment
  "buddy-coder.mobileNumber": "9270416640",    // Your mobile number
  "buddy-coder.autoSend": false                // Auto-send on Enter
}
```

## 📱 Authentication

Uses the same authentication system as your Buddy mobile app:

### Test Accounts (OTP: `123456`)
- `9270416640`
- `9579348057` 
- `1234567890`

### Production Accounts
- Enter your real mobile number
- OTP will be sent to your registered email
- Check backend terminal for OTP if email fails

## 🎛️ API Configuration

The extension uses `apiConfig.json` to manage different environments:

```json
{
  "environments": {
    "local": {
      "name": "Local Development",
      "serverUrl": "http://localhost:8000",
      "description": "Local development server"
    },
    "production": {
      "name": "Production Server", 
      "serverUrl": "https://your-server.com",
      "description": "Production server"
    }
  },
  "endpoints": {
    "auth": {
      "requestOtp": "/auth/request-otp",
      "verifyOtp": "/auth/verify-otp"
    },
    "chat": {
      "vscode": "/api/vscode/chat"
    }
  }
}
```

## 🔧 Commands

| Command | Description | Shortcut |
|---------|-------------|----------|
| `Buddy: Open Chat` | Opens the chat panel | - |
| `Buddy: Clear Chat History` | Clears all messages | - |
| `Buddy: Switch API Environment` | Change server environment | - |
| `Buddy: Toggle Chat` | Show/hide chat panel | - |

## 🐛 Troubleshooting

### Login Issues
- **404 Error**: Check if backend server is running on the correct port
- **Authentication Failed**: Verify your mobile number is registered
- **OTP Issues**: Check terminal output for test account OTP

### Connection Issues  
- **Endpoint Not Found**: Switch to correct environment using ⚙️ button
- **Server Unavailable**: Verify backend server is running
- **CORS Issues**: Check backend CORS settings allow VS Code extension

### Backend Setup Required
Make sure your Buddy backend is running:
```bash
cd buddy_backend
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## 📦 Development

### Build Extension
```bash
npm run compile        # Compile TypeScript
npm run watch         # Watch for changes
```

### Package Extension
```bash
npm install -g vsce
vsce package
```

### Debug
- Set breakpoints in TypeScript code
- Press F5 to start debugging
- Use Developer Tools in Extension Development Host

## 🌐 Backend Integration

This extension communicates with:
- **Authentication**: `/auth/request-otp`, `/auth/verify-otp`
- **Chat**: `/api/vscode/chat` 
- **User Management**: Standard Buddy backend user system

## 🎨 UI Features

- **Gradient Design**: Matches Buddy app aesthetics
- **Environment Badge**: Shows current server environment  
- **Typing Indicators**: Real-time chat experience
- **Error Handling**: User-friendly error messages
- **Responsive Design**: Adapts to VS Code theme

## 💡 Usage Tips

1. **Test Account**: Use `9270416640` with OTP `123456` for quick testing
2. **Environment Switching**: Use ⚙️ button to quickly switch between local/production
3. **Keyboard Shortcuts**: Enter to send, Shift+Enter for new line
4. **Error Messages**: Check terminal output for detailed error information

## 🔄 Updates

The extension automatically uses the latest API configuration. To update:
1. Pull latest changes from repository
2. Run `npm run compile`
3. Restart VS Code extension development host

## 📝 License

This project is part of the Buddy AI ecosystem.