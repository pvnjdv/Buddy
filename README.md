<![Buddy Logo](https://github.com/pvnjdv/Buddy/blob/main/buddy_app/assets/icon/app_icon.jpg?raw=true)

# 🧑‍💻 Buddy: Cross-Platform AI Project Manager & Copilot Alternative

**Buddy** is a cross-platform, AI-powered productivity suite for developers and teams. It acts as a GitHub Copilot alternative, offering project management, code assistance, remote device access, and seamless integration across desktop, mobile, and web.

---

## ✨ Key Features

- **🤖 AI Assistant**
  - Context-aware project planning, code generation, note-taking, and productivity flows
  - RAG-enhanced responses, dynamic templates, multi-language support
  - Full context awareness and intelligent reasoning

- **🌐 Cross-Platform**
  - Fully supported on Desktop, Mobile (Flutter), and Web
  - Unified, gradient-themed UI

- **💻 GitHub Copilot Alternative**
  - Natural language code explanation, generation, and refactoring
  - VS Code extension with contextual help, shortcuts, and command palette

- **📱 Remote Device Management**
  - Register devices and access remotely for coding/project tasks
  - Manage, automate, and sync across registered devices

---

## 🧠 AI & Application Modes

- **Cloud API Mode:** Fast, up-to-date, requires internet
- **Local On-Device AI:** Private, offline, requires compatible model files (`.gguf`, `.tflite`)
- **Creative Mode:** For creative and experimental AI tasks
- **VS Code Extension Modes:**  
  - 🧠 Standard Mode (Balanced)  
  - ❓ Ask Mode (Questions)  
  - 🤖 Agent Mode (Autonomous tasks)  
  - 🧮 Reasoning Mode (Deep thinking)  
  - 🔬 Deep Think Mode (Comprehensive analysis)

---

## ⚙️ Environment & Customization

- **Environment Switching:**  
  - Toggle between local, staging, and production servers (one-click)
  - JSON config for server URLs and environment descriptions

- **Customization:**
  - Theme: auto/light/dark
  - Context capture: automatic file inclusion for code queries
  - Max context lines (default: 100)
  - Inline suggestions (future support)
  - Auto-send messages on Enter
  - Mobile number + OTP authentication

---

## 🚀 Productivity & Automation

- **Project Templates:** Multi-platform templates, integrated build systems
- **Automated Testing Frameworks**
- **Git Version Control**
- **Code Snippets Library**
- **Terminal Automation:**  
  - Pre-built workflows, build/deployment scripts, Git automation, macros
- **DevOps Integration:**  
  - CI/CD pipeline, container deployment, feature status tracking, deployment history

---

## 🌐 Collaboration

- Real-time code collaboration
- Shared project workspaces
- Live cursor tracking
- Comment and review system

---

## 📱 Mobile App Features

- Live Preview, Feature Status, User Feedback
- Deployment history & environment status

---

## 🛠️ VS Code Extension

- Integrated Buddy AI chat panel
- Contextual code explanations, reviews, refactoring, project planning
- Keyboard shortcuts, command palette, environment badge in UI

---

## 🔒 Authentication

- Secure mobile number + OTP across all platforms
- Robust session management, token refresh, error handling

---

## 📦 Quick Setup

### Mobile (Flutter)
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
cd buddy_coder
npm install
npm run compile
```

---

## 🗂️ Configuration Samples

**VS Code:**
```json
{
  "buddy-coder.environment": "local",
  "buddy-coder.mobileNumber": "9270416640",
  "buddy-coder.autoSend": false
}
```

**API Config (`apiConfig.json`):**
```json
{
  "environments": {
    "local": {"serverUrl": "http://localhost:8000"},
    "production": {"serverUrl": "https://your-server.com"}
  }
}
```

---

## 💡 Usage Tips

- Use test account: `9270416640` & OTP `123456`
- Switch environments with ⚙️ button or settings
- Keyboard shortcuts: Enter to send, Shift+Enter for newline
- Check terminal output for detailed error info

---

## 📝 License

Licensed under [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html).

---

> **Contribute, collaborate, or try Buddy now! For the latest code, visit**  
> [github.com/pvnjdv/Buddy](https://github.com/pvnjdv/Buddy)