# Buddy

**Buddy** is a cross-platform AI-powered project manager and productivity suite. It serves as a GitHub Copilot alternative, featuring remote device access, intelligent workflow automation, and seamless integration across desktop, mobile, and web platforms.

## Key Features

- **AI Project Manager**  
  - Advanced assistant for project planning, flow generation, and productivity tasks
  - Understands complex requests and provides actionable, structured responses
  - Full context awareness and intelligent reasoning
- **Cross-Platform**  
  - Builds available for desktop, mobile (Flutter), and web
  - Unified experience and design across all platforms
- **Copilot Alternative**  
  - Natural language code generation, explanation, and refactoring
  - Integrated chat panel for coding assistance
  - Support for VS Code extension with keyboard shortcuts and context menus
- **Remote Device Management**  
  - Access and manage registered devices remotely
  - Perform coding tasks, project management, and automation across devices
- **Authentication**  
  - Secure mobile number + OTP authentication across all platforms
- **Environment Switching**  
  - Easily switch between local, staging, and production servers

## Technologies

- **Backend:** Python (FastAPI), AI modules, device management, GitHub API integration
- **Mobile:** Dart (Flutter)
- **VS Code Extension:** TypeScript, Node.js
- **Web/Desktop:** Electron, Flutter, or other supported frameworks
- **License:** GNU GPL v3.0

## Setup

### Mobile
```bash
flutter pub get
flutter run
```

### Backend
```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### VS Code Extension
```bash
npm install
npm run compile
```

## Usage

- **Test Account:** Mobile `9270416640`, OTP `123456`
- **VS Code:**  
  - `Ctrl+Shift+B`: Open chat
  - `Ctrl+Shift+A`: Ask about code selection
  - `Ctrl+Shift+G`: Generate code
  - `Ctrl+Shift+E`: Explain code
  - Environment switching via settings or UI
- **Remote Management:**  
  - Register devices through the app or web UI
  - Access and automate coding/project tasks remotely

## License

Licensed under [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
