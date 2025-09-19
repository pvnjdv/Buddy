# Buddy Code Editor Sync Extension

A VS Code extension that provides seamless synchronization between VS Code and the Buddy Code Editor mobile app.

## Features

- 🔄 **Real-time Sync**: Automatically sync code changes between VS Code and Buddy mobile app
- 📁 **Project Management**: Open and manage Buddy projects directly in VS Code
- 🔍 **GitHub Integration**: Push and pull changes to/from GitHub repositories
- 💬 **AI Assistance**: Get AI-powered code suggestions and help
- 🌐 **Cross-platform**: Works with Buddy's mobile and desktop editors

## Installation

### Option 1: From VS Code Marketplace (Recommended)
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "Buddy Code Editor Sync"
4. Click Install

### Option 2: Manual Installation (Development)
Since the extension cannot be packaged due to Node.js version constraints, you can install it manually for development:

1. **Clone and Build**:
   ```bash
   git clone <repository-url>
   cd vscode-extension
   npm install
   npm run compile
   ```

2. **Install in VS Code**:
   - Open VS Code
   - Press `Ctrl+Shift+P` to open Command Palette
   - Run `Extensions: Install from VSIX...`
   - Since we can't create a VSIX file, use the development host instead:
     - Press `F5` in the extension folder to launch Extension Development Host
     - Test the extension in the new VS Code window

3. **Alternative Manual Install** (Advanced):
   - Copy the entire `vscode-extension` folder to `~/.vscode/extensions/`
   - Rename it to `buddy.buddy-vscode-extension-1.0.0`
   - Reload VS Code window

### Option 3: Development Mode
1. Open the `vscode-extension` folder in VS Code
2. Press `F5` to launch Extension Development Host
3. Test all features in the new window
4. The extension will reload automatically on code changes

## Setup

1. **Install the Extension** in VS Code
2. **Configure Buddy Connection**:
   - Open VS Code settings (Ctrl+,)
   - Search for "Buddy"
   - Set your Buddy server URL (default: `http://localhost:8000`)
   - Enter your Buddy API key
3. **Connect to Buddy**:
   - Use Command Palette (Ctrl+Shift+P)
   - Run "Buddy: Connect"
   - Enter your credentials when prompted

## Usage

### Connecting to Buddy
- **Command**: `Buddy: Connect`
- **Shortcut**: Status bar button
- Connects VS Code to your Buddy account

### Opening Projects
- **Command**: `Buddy: Open Project`
- Browse and open your Buddy projects in VS Code

### Syncing Changes
- **Auto-sync**: Changes sync automatically (configurable)
- **Manual sync**: `Buddy: Sync`
- **Push to Buddy**: `Buddy: Push`
- **Pull from Buddy**: `Buddy: Pull`

### Git Operations
- **Push**: Push local changes to GitHub repository
- **Pull**: Pull latest changes from GitHub repository
- **Status**: Check repository status
- **Commit**: Commit changes with AI-generated messages

## Configuration

### Settings
- `buddy.serverUrl`: Buddy backend server URL
- `buddy.apiKey`: Your Buddy API authentication key
- `buddy.autoSync`: Enable/disable automatic synchronization
- `buddy.syncInterval`: Sync interval in milliseconds

### Example settings.json
```json
{
  "buddy.serverUrl": "http://localhost:8000",
  "buddy.apiKey": "your-api-key-here",
  "buddy.autoSync": true,
  "buddy.syncInterval": 5000
}
```

## Architecture

### Components
- **Extension Host**: Main VS Code extension logic
- **Sync Service**: Handles communication with Buddy backend
- **File Watcher**: Monitors file changes for auto-sync
- **Git Service**: Manages Git operations
- **WebSocket Client**: Real-time communication

### Communication Flow
```
VS Code Extension ↔ Buddy Backend API
       ↓
   WebSocket Connection
       ↓
   Real-time Sync
       ↓
Mobile App ↔ VS Code
```

## Development

### Prerequisites
- Node.js 16+
- VS Code
- Buddy backend server running

### Building
```bash
npm install
npm run compile
```

### Testing
```bash
npm run test
```

### Debugging
1. Press F5 in VS Code
2. New window opens with extension loaded
3. Test functionality in the new window

## API Reference

### REST Endpoints
- `GET /api/sync/projects` - Get user projects
- `POST /api/sync/file-change` - Sync file changes
- `POST /api/sync/project-update` - Update project info

### WebSocket Events
- `file_changed` - File modified in another client
- `project_updated` - Project metadata changed
- `sync_request` - Request for sync data

## Troubleshooting

### Connection Issues
1. Check Buddy server is running
2. Verify API key is correct
3. Check network connectivity
4. Review VS Code output panel for errors

### Sync Problems
1. Ensure project is open in both clients
2. Check file permissions
3. Verify Git repository status
4. Review sync logs

### Git Operations
1. Ensure Git is installed and configured
2. Check repository remote URLs
3. Verify authentication credentials
4. Review Git output in terminal

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- 📧 Email: support@buddyapp.com
- 💬 Discord: [Buddy Community](https://discord.gg/buddy)
- 📖 Docs: [Buddy Documentation](https://docs.buddyapp.com)

---

**Made with ❤️ by the Buddy Team**