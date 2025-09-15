# Buddy AI - Your Intelligent Companion

<div align="center">

![Buddy AI Logo](buddy_app/assets/icon/app_icon.jpg)

**🤖 AI-Powered Productivity • 📱 Cross-Platform • 🛡️ Privacy-First**

[![Flutter](https://img.shields.io/badge/Flutter-v3.8.1-blue.svg)](https://flutter.dev/)
[![Python](https://img.shields.io/badge/Python-3.12+-green.svg)](https://python.org/)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-v2.16-orange.svg)](https://tensorflow.org/lite)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

[📱 Download](#installation) • [📖 Documentation](#documentation) • [🚀 Quick Start](#quick-start) • [🤝 Contributing](#contributing)

</div>

---

## ✨ What is Buddy?

**Buddy** is a comprehensive AI-powered companion that combines intelligent conversations, project management, development tools, and smart automation into one powerful platform. Whether you're coding, planning projects, or managing your daily tasks, Buddy adapts to your needs and amplifies your productivity.

### 🎯 Key Highlights

- **🤖 Dual AI Modes**: Cloud-based API or private on-device processing
- **📋 Visual Project Management**: Flows, Kanban boards, and smart planning
- **💻 Development Environment**: Code editor, terminal, and VS Code integration  
- **🔧 Smart Automation**: Device control, macros, and IoT management
- **👥 Team Collaboration**: Shared workspaces and knowledge management
- **🛡️ Privacy-First**: Local AI processing with encrypted storage

## 🚀 Quick Start

### What You Can Do

**New to Buddy?** Check out our comprehensive guides:

- **[📖 What You Can Do](./WHAT_YOU_CAN_DO.md)** - Complete feature overview
- **[⚡ Quick Start Guide](./QUICK_START.md)** - Get started in minutes
- **[🤖 On-Device AI Guide](./docs/ON_DEVICE_AI_USAGE_GUIDE.md)** - Setup local AI processing

### Installation Options

#### 📱 **Mobile (Android)**
```bash
# Clone the repository
git clone https://github.com/pvnjdv/Buddy.git
cd Buddy/buddy_app

# Install dependencies
flutter pub get

# Setup Android AI (optional)
chmod +x ../setup_llama_android.sh
../setup_llama_android.sh

# Build and install
flutter build apk
flutter install
```

#### 🖥️ **Desktop (Windows/Mac/Linux)**
```bash
# Flutter Desktop setup
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop

# Build for your platform
flutter build windows  # or macos/linux
```

#### 🌐 **Backend Server (Optional)**
```bash
cd buddy_backend

# Install Python dependencies
pip install -r requirements.txt

# Start the server
uvicorn app.main:app --reload
```

## 🎯 Core Features

### 🤖 AI Conversations
- **Natural Language Processing**: Chat naturally with your AI companion
- **Context Awareness**: Buddy remembers your conversation history
- **Custom Personas**: Create specialized AI assistants for different tasks
- **On-Device Privacy**: Run AI models locally for complete privacy

### 📋 Project Management
- **Visual Flows**: Create step-by-step project roadmaps
- **Smart Planning**: AI-generated project plans and timelines
- **Kanban Boards**: Organize tasks with drag-and-drop simplicity
- **Progress Tracking**: Monitor milestones and completion status

### 💻 Development Tools
- **Integrated IDE**: Full-featured code editor with syntax highlighting
- **AI Code Assistance**: Smart completions, debugging, and suggestions
- **Terminal Integration**: Run commands and scripts directly in the app
- **Version Control**: Git integration for seamless code management

### 🔧 Automation & Control
- **Device Management**: Control computers, IoT devices, and smart systems
- **Macro Automation**: Create complex workflows for repetitive tasks
- **Network Discovery**: Automatically find and connect to devices
- **System Monitoring**: Real-time performance and health tracking

### 👥 Collaboration
- **Team Workspaces**: Shared environments for collaborative projects
- **Real-Time Sync**: See updates and changes instantly
- **Knowledge Base**: Organize and share team knowledge effectively
- **Role-Based Access**: Secure permissions and access control

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │  Python Backend │    │   AI Services   │
│                 │    │                 │    │                 │
│ • Chat UI       │◄──►│ • REST API      │◄──►│ • Cloud AI      │
│ • Project Mgmt  │    │ • WebSockets    │    │ • Local Models  │
│ • Code Editor   │    │ • Database      │    │ • TensorFlow    │
│ • Device Control│    │ • Auth System   │    │ • Custom Logic  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Technology Stack

- **Frontend**: Flutter (Dart) - Cross-platform mobile and desktop
- **Backend**: FastAPI (Python) - High-performance async API
- **AI Processing**: TensorFlow Lite, Cloud APIs (Groq, OpenAI)
- **Database**: SQLite (local), PostgreSQL (server)
- **Real-Time**: WebSockets for live collaboration
- **Security**: JWT authentication, encrypted storage

## 📖 Documentation

### User Guides
- **[Complete Feature Guide](./WHAT_YOU_CAN_DO.md)** - Everything Buddy can do
- **[Quick Reference](./QUICK_START.md)** - Essential features overview
- **[On-Device AI Setup](./docs/ON_DEVICE_AI_USAGE_GUIDE.md)** - Privacy-focused AI processing

### Technical Documentation
- **[On-Device Implementation](./docs/ON_DEVICE_AI_IMPLEMENTATION.md)** - Technical AI integration details
- **[TensorFlow Lite Integration](./TFLITE_INTEGRATION_REPORT.md)** - Mobile AI implementation
- **[Desktop AI Support](./DESKTOP_TFLITE_SUPPORT.md)** - Cross-platform AI guide

### Development
- **[API Documentation](./buddy_backend/README.md)** - Backend API reference
- **[Flutter App Structure](./buddy_app/README.md)** - Frontend architecture
- **[Contributing Guidelines](./CONTRIBUTING.md)** - How to contribute (coming soon)

## 🛡️ Privacy & Security

**Privacy-First Design**: Buddy is built with privacy as a core principle:

- **🔒 Local AI Processing**: Run AI models directly on your device
- **🔐 Encrypted Storage**: All data is encrypted at rest and in transit
- **🚫 No Tracking**: No telemetry or user tracking
- **⚙️ Full Control**: You decide what data to share and where

### On-Device AI Benefits
- ✅ Complete privacy - data never leaves your device
- ✅ Offline functionality - works without internet
- ✅ Fast responses - no network latency
- ✅ Cost-effective - no API fees for local processing

## 🤝 Contributing

We welcome contributions from the community! Whether you're fixing bugs, adding features, or improving documentation, your help makes Buddy better for everyone.

### Ways to Contribute
- 🐛 **Report Issues**: Found a bug? Let us know!
- 💡 **Suggest Features**: Have an idea? We'd love to hear it!
- 🔧 **Code Contributions**: Submit pull requests for improvements
- 📖 **Documentation**: Help improve our guides and documentation

### Development Setup
```bash
# 1. Fork and clone the repository
git clone https://github.com/yourusername/Buddy.git

# 2. Setup Flutter development environment
flutter doctor

# 3. Install dependencies
cd buddy_app && flutter pub get
cd ../buddy_backend && pip install -r requirements.txt

# 4. Start development
flutter run  # Start the app
uvicorn app.main:app --reload  # Start the backend
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Support & Community

- **💬 Discussions**: Join our [GitHub Discussions](https://github.com/pvnjdv/Buddy/discussions)
- **🐛 Issues**: Report bugs or request features in [Issues](https://github.com/pvnjdv/Buddy/issues)
- **📧 Contact**: Reach out to the maintainers for questions

---

<div align="center">

**Ready to boost your productivity with AI?**

[🚀 Get Started](./QUICK_START.md) • [📖 Read the Docs](./WHAT_YOU_CAN_DO.md) • [⭐ Star on GitHub](https://github.com/pvnjdv/Buddy)

Made with ❤️ by the Buddy AI community

</div>