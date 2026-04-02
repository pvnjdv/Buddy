# Frequently Asked Questions (FAQ)

## General Questions

### What is Buddy AI?
Buddy AI is a comprehensive AI-powered companion that combines intelligent conversations, project management, development tools, and smart automation. It's designed to boost your productivity across work, learning, and personal projects.

### Is Buddy free to use?
Yes! Buddy is open-source software that you can use, modify, and distribute freely under the MIT license. You only pay for optional cloud AI services if you choose to use them.

### What platforms does Buddy support?
- **Mobile**: Android and iOS
- **Desktop**: Windows, macOS, and Linux  
- **Web**: Progressive Web App (PWA) support

## Privacy & Security

### How private is my data?
Very private! Buddy offers:
- **On-device AI processing**: Your conversations never leave your device
- **Local storage**: Data stored encrypted on your device
- **No tracking**: We don't collect or sell your personal data
- **You control sharing**: Choose what data to sync or backup

### What's the difference between cloud AI and on-device AI?
- **Cloud AI**: Uses external services (faster, more powerful, requires internet)
- **On-device AI**: Runs locally on your device (private, offline, uses your device's resources)

### Is my code secure when using the development features?
Yes! When using on-device AI, your code never leaves your device. Even with cloud AI, you control what code snippets to share for assistance.

## Features & Capabilities

### What can I do with the AI chat?
- Ask questions and get intelligent responses
- Get help with coding, writing, and problem-solving
- Create custom AI personas for specialized tasks
- Maintain context across long conversations
- Use voice input and multimedia sharing

### How does project management work?
- **Flows**: Create visual project roadmaps with timelines
- **Kanban boards**: Organize tasks with drag-and-drop
- **AI planning**: Get AI-generated project plans and milestones
- **Progress tracking**: Monitor completion and time estimates
- **Team collaboration**: Share projects and work together

### What development tools are included?
- **Code editor**: Syntax highlighting for multiple languages
- **AI assistance**: Code completions, debugging help, and suggestions
- **Terminal**: Integrated command line interface
- **Version control**: Git integration for code management
- **VS Code sync**: Connect with Visual Studio Code

### What is the Dock feature?
The Dock allows you to:
- Discover and control devices on your network
- Create automation macros for repetitive tasks
- Monitor system performance and health
- Control IoT devices and smart home systems

## Technical Questions

### What AI models does Buddy support?
- **Cloud**: Groq API, OpenAI GPT models, custom API endpoints
- **On-device**: TensorFlow Lite models (.tflite), GGUF models (.gguf)
- **Popular models**: Llama-2, Mistral, Phi-2, CodeLlama, and more

### What are the system requirements?
**Minimum:**
- **Mobile**: Android 7.0+ or iOS 12+, 3GB RAM
- **Desktop**: Windows 10+/macOS 10.14+/Ubuntu 18.04+, 4GB RAM
- **Storage**: 2GB free space (more for AI models)

**Recommended for on-device AI:**
- 6GB+ RAM for smooth operation
- 10GB+ storage for multiple AI models

### How do I set up on-device AI?
1. Go to Settings → AI Settings
2. Choose "Local On-Device AI"
3. Download or select a compatible AI model (.tflite or .gguf)
4. The system will validate if your device can handle the model
5. Start chatting privately!

### Can I use multiple AI models?
Yes! You can:
- Switch between cloud and on-device AI anytime
- Load different models for different tasks
- Create AI personas that use specific models
- Combine multiple AI services for optimal results

## Setup & Installation

### How do I install Buddy?
**Option 1: Download Release**
- Visit our [GitHub releases page](https://github.com/pvnjdv/Buddy/releases)
- Download for your platform
- Install and run

**Option 2: Build from Source**
```bash
git clone https://github.com/pvnjdv/Buddy.git
cd Buddy/buddy_app
flutter pub get
flutter run
```

### Do I need to run a backend server?
**No, not required!** Buddy can work in two modes:
- **Standalone**: Full functionality with local AI and data
- **Server mode**: Additional features like team collaboration and cloud sync

### How do I get API keys for cloud AI?
1. **Groq** (recommended): Sign up at [groq.com](https://groq.com) for free API access
2. **OpenAI**: Create account at [openai.com](https://openai.com) and get API key
3. Add keys in Settings → AI Settings → Cloud AI Configuration

## Troubleshooting

### Buddy says my device isn't suitable for on-device AI
This warning can be overly conservative. Try:
1. Close other apps to free memory
2. Restart Buddy for a clean memory state
3. Try a smaller model first (like TinyLlama)
4. Restart your device if needed

### My AI model won't load
**Check these common issues:**
1. **File format**: Ensure you're using .tflite or .gguf files
2. **Model size**: Make sure the model fits in your device memory
3. **File location**: Verify the model file is accessible
4. **Memory**: Close other apps and try again

### The app is running slowly
**Performance tips:**
1. **Close background apps** to free memory
2. **Use smaller AI models** for faster responses
3. **Restart the app** to clear memory leaks
4. **Check storage space** - low storage affects performance

### I can't connect to my backend server
1. **Check server status**: Ensure the backend is running
2. **Verify URL**: Check the server address in Settings
3. **Network**: Ensure you're on the same network
4. **Firewall**: Check firewall settings aren't blocking the connection

## Advanced Usage

### Can I create custom AI personas?
Yes! Go to Settings → AI Personas to:
- Create personas with specific personalities
- Set custom response styles and behaviors
- Switch between personas for different tasks
- Share personas with team members

### How do I backup my data?
**Automatic options:**
- Enable cloud sync in Settings → Data & Sync
- Data backs up to your chosen cloud provider

**Manual options:**
- Export conversations as text/JSON
- Export projects and flows
- Backup AI personas and settings

### Can I integrate Buddy with other tools?
**Current integrations:**
- VS Code for development
- Git repositories
- System terminal and command line
- File managers and storage services

**Planned integrations:**
- Calendar and scheduling apps
- Note-taking applications
- Communication platforms
- Cloud storage services

### How do I contribute to Buddy's development?
1. **Report bugs**: Create issues on GitHub
2. **Suggest features**: Share ideas in discussions
3. **Contribute code**: Submit pull requests
4. **Improve docs**: Help enhance documentation
5. **Share experiences**: Help other users in the community

## Getting Help

### Where can I get support?
- **Documentation**: Check our comprehensive guides
- **GitHub Issues**: Report bugs and ask technical questions
- **GitHub Discussions**: Community Q&A and feature discussions
- **FAQ**: This document for common questions

### How do I report a bug?
1. Go to [GitHub Issues](https://github.com/pvnjdv/Buddy/issues)
2. Click "New Issue"
3. Use the bug report template
4. Include steps to reproduce, expected vs actual behavior
5. Add relevant logs or screenshots

### How do I request a new feature?
1. Check existing [GitHub Discussions](https://github.com/pvnjdv/Buddy/discussions)
2. If not already discussed, create a new discussion
3. Describe your use case and proposed solution
4. Engage with the community for feedback

---

**Still have questions?** 
- Check our [complete documentation](./WHAT_YOU_CAN_DO.md)
- Join the [GitHub discussions](https://github.com/pvnjdv/Buddy/discussions)
- Create an [issue](https://github.com/pvnjdv/Buddy/issues) for technical problems