# Buddy App - Flutter Frontend

**The cross-platform mobile and desktop application for Buddy AI**

This Flutter application provides the user interface and client-side functionality for Buddy AI, your intelligent companion for productivity, development, and automation.

## 🚀 Features

- **🤖 AI Chat Interface**: Natural conversations with context-aware AI
- **📱 Cross-Platform**: Runs on Android, iOS, Windows, macOS, and Linux
- **🔒 On-Device AI**: Local AI processing with TensorFlow Lite
- **📋 Project Management**: Visual flows and Kanban boards
- **💻 Code Editor**: Integrated development environment
- **🔧 Device Control**: Smart automation and device management
- **👥 Collaboration**: Real-time team workspaces

## 📋 Requirements

- **Flutter SDK**: v3.8.1 or higher
- **Dart SDK**: v3.8.1 or higher
- **Android SDK**: API level 21+ (for Android builds)
- **Xcode**: 14+ (for iOS builds)
- **Platform Tools**: Windows/macOS/Linux development tools (for desktop builds)

## 🛠️ Installation & Setup

### 1. Clone Repository
```bash
git clone https://github.com/pvnjdv/Buddy.git
cd Buddy/buddy_app
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Setup Platform-Specific Requirements

#### Android
```bash
# Setup Android NDK for on-device AI (optional)
chmod +x ../setup_llama_android.sh
../setup_llama_android.sh
```

#### Desktop
```bash
# Enable desktop platforms
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop  
flutter config --enable-linux-desktop
```

### 4. Configure Backend Connection
Update the API configuration in `lib/config/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = 'http://your-backend-url:8000';
  // ... other configuration
}
```

### 5. Build & Run

#### Development
```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

#### Production Builds
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Desktop
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## 📁 Project Structure

```
buddy_app/
├── lib/
│   ├── config/           # App configuration
│   ├── models/           # Data models
│   ├── screens/          # UI screens
│   │   ├── buddy/        # AI chat interface
│   │   ├── flow/         # Project management
│   │   ├── dock/         # Device control
│   │   ├── settings/     # App settings
│   │   └── ...
│   ├── services/         # Business logic services
│   │   ├── ai/           # AI processing services
│   │   ├── databases/    # Local data storage
│   │   ├── auth/         # Authentication
│   │   └── ...
│   ├── widgets/          # Reusable UI components
│   └── main.dart         # App entry point
├── android/              # Android-specific code
├── ios/                  # iOS-specific code
├── windows/              # Windows-specific code
├── macos/                # macOS-specific code
├── linux/                # Linux-specific code
├── web/                  # Web-specific code
└── assets/               # Static assets
```

## 🔧 Key Technologies

- **Framework**: Flutter 3.8.1+ (Dart)
- **State Management**: Riverpod
- **Local Storage**: SQLite, SharedPreferences
- **AI Processing**: TensorFlow Lite
- **HTTP Client**: Dart HTTP package
- **Real-Time**: WebSocket connections
- **File Management**: Path Provider, File Picker

## 🤖 AI Features

### Cloud AI
- Groq API integration for high-performance cloud AI
- OpenAI API support for advanced language models
- Custom API endpoints for specialized AI services

### On-Device AI
- TensorFlow Lite integration for local AI processing
- Support for GGUF model format (via native plugins)
- Automatic device capability detection
- Memory optimization and safety checks

### AI Personas
- Create custom AI personalities for different tasks
- Switch between personas for specialized assistance
- Save and share persona configurations

## 📱 Platform-Specific Features

### Mobile (Android/iOS)
- Native file picker integration
- System-level notifications
- Background processing capabilities
- Hardware-accelerated AI processing

### Desktop (Windows/macOS/Linux)
- System tray integration
- File system access
- Window management
- Cross-platform keyboard shortcuts

### Web
- Progressive Web App (PWA) support
- Browser-based file handling
- WebAssembly AI processing fallback

## 🛡️ Security & Privacy

### Data Protection
- Local encryption for sensitive data
- Secure token-based authentication
- Optional cloud backup with encryption
- User-controlled data sharing preferences

### On-Device Processing
- Complete privacy with local AI models
- No data transmission for AI processing
- Offline functionality for sensitive workflows
- User control over model selection

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run widget tests
flutter test test/widget_test.dart
```

## 🐛 Debugging

### Development Tools
```bash
# Enable debug mode
flutter run --debug

# Performance profiling
flutter run --profile

# Widget inspector
flutter inspector
```

### Logging
The app uses structured logging for debugging:
```dart
import 'package:logging/logging.dart';

final logger = Logger('ServiceName');
logger.info('Debug information');
```

## 📦 Dependencies

### Core Dependencies
- `flutter`: Cross-platform UI framework
- `http`: HTTP client for API communication
- `shared_preferences`: Local key-value storage
- `sqflite`: SQLite database integration
- `flutter_riverpod`: State management
- `tflite_flutter`: TensorFlow Lite for AI

### UI Dependencies
- `flutter_chat_ui`: Chat interface components
- `flutter_staggered_grid_view`: Advanced grid layouts
- `google_fonts`: Custom typography
- `flutter_highlight`: Code syntax highlighting

### Utility Dependencies
- `path_provider`: File system path access
- `file_picker`: File selection dialogs
- `device_info_plus`: Device information
- `permission_handler`: Runtime permissions

## 🚀 Deployment

### App Stores
Prepare for app store deployment:
```bash
# Android Play Store
flutter build appbundle --release

# iOS App Store
flutter build ios --release
```

### Desktop Distribution
Create installers for desktop platforms:
```bash
# Windows installer
flutter build windows --release
# Then use tools like Inno Setup or NSIS

# macOS app bundle
flutter build macos --release
# Then notarize for distribution
```

## 🤝 Contributing

See the main [Contributing Guidelines](../CONTRIBUTING.md) for details on:
- Code style and formatting
- Testing requirements
- Pull request process
- Development workflow

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**For complete documentation**, see the main [README](../README.md) and [feature guides](../WHAT_YOU_CAN_DO.md).
