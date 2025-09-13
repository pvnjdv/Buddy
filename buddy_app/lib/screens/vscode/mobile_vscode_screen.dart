import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/vscode_integration_service.dart';
import '../../models/flow_models.dart';
import '../../models/project_model.dart';
import '../buddy_code_editor/buddy_code_editor_screen.dart';
import 'dart:io';

/// Mobile VS Code screen with windowed interface and sizing controls
class MobileVSCodeScreen extends StatefulWidget {
  final VSCodeSession session;
  final ProjectFlow project;
  final VoidCallback? onSync;
  final VoidCallback? onClose;

  const MobileVSCodeScreen({
    super.key,
    required this.session,
    required this.project,
    this.onSync,
    this.onClose,
  });

  @override
  State<MobileVSCodeScreen> createState() => _MobileVSCodeScreenState();
}

class _MobileVSCodeScreenState extends State<MobileVSCodeScreen>
    with TickerProviderStateMixin {
  bool _isSyncing = false;
  bool _isLaunching = false;
  bool _isFullScreen = false;
  double _windowScale = 1.0;
  late AnimationController _scaleController;
  late AnimationController _opacityController;
  WebViewController? _webViewController;
  bool _isWebViewLoading = true;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeVSCode();
  }

  void _initializeControllers() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0,
    );
    _opacityController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
  }

  void _initializeVSCode() {
    // Check if WebView is supported on this platform
    if (kIsWeb) {
      // For web, we'll use a fallback
      return;
    }

    // Initialize WebView for supported platforms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
    });
  }

  void _initializeWebView() {
    try {
      String vscodeUrl = widget.session.vscodeUrl ?? 'https://vscode.dev';
      if (!vscodeUrl.startsWith('http')) {
        vscodeUrl = 'https://$vscodeUrl';
      }

      // Optimize VS Code URL with performance parameters
      final optimizedUrl = _buildOptimizedVSCodeUrl(vscodeUrl);

      // Optimized WebView initialization
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF1e1e1e))
        // Enable performance optimizations
        ..enableZoom(true)
        ..setUserAgent(
          'Mozilla/5.0 (Mobile; rv:109.0) Gecko/111.0 Firefox/111.0',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _loadingProgress = progress / 100.0;
                });
              }
              debugPrint('WebView loading progress: $progress%');
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isWebViewLoading = true;
                  _loadingProgress = 0.0;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                  _loadingProgress = 1.0;
                });
                // Inject performance optimizations
                _injectPerformanceOptimizations();
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView error: ${error.description}');
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showWebViewError(error.description);
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              // Allow file system access and VS Code URLs
              if (request.url.startsWith('vscode://') ||
                  request.url.startsWith('file://') ||
                  request.url.contains('vscode.dev') ||
                  request.url.contains('github.dev')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(optimizedUrl));
    } catch (e) {
      debugPrint('WebView initialization error: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWebViewError('Failed to initialize WebView: $e');
        });
      }
    }
  }

  String _buildOptimizedVSCodeUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);

    // Add optimized parameters for full VS Code interface
    params.addAll({
      'theme': 'dark',
      'embed': 'true',
      'hideNavigation': 'false', // Keep navigation for full functionality
      'hideActivityBar': 'false', // Keep activity bar for file access
      'hideStatusBar': 'false', // Keep status bar for info
      'hidePanel': 'false', // Keep panel for terminal
      'hideTabs': 'false', // Keep tabs for file management
      'minimap': 'true', // Keep minimap for navigation
      'wordWrap': 'on',
      'fontSize': '16', // Larger font for mobile
      'fontFamily': 'Monaco, Consolas, monospace',
      'autoSave': 'afterDelay',
      'autoSaveDelay': '1000',
      'editor.mouseWheelZoom': 'true',
      'editor.wordWrap': 'on',
      'editor.lineNumbers': 'on',
      'editor.minimap.enabled': 'true',
      'editor.scrollbar.verticalScrollbarSize': '18',
      'editor.scrollbar.horizontalScrollbarSize': '18',
      'workbench.startupEditor': 'welcomePage',
      'workbench.colorTheme': 'Default Dark+',
      'workbench.sideBar.location': 'left',
      'workbench.panel.defaultLocation': 'bottom',
      'workbench.activityBar.visible': 'true',
      'workbench.statusBar.visible': 'true',
      'explorer.openEditors.visible': 'true',
      // Enable file system access features
      'files.enableTrash': 'false',
      'files.autoSave': 'afterDelay',
      'files.autoSaveDelay': '1000',
      // Mobile optimizations
      'editor.fontSize': '16',
      'editor.lineHeight': '1.6',
      'editor.padding.top': '8',
      'editor.padding.bottom': '8',
      'terminal.integrated.fontSize': '14',
      'debug.console.fontSize': '14',
    });

    return uri.replace(queryParameters: params).toString();
  }

  void _injectPerformanceOptimizations() {
    if (_webViewController != null) {
      // Inject JavaScript for better mobile experience and file access
      _webViewController!.runJavaScript('''
        // Wait for VS Code to fully load
        function waitForVSCode() {
          if (typeof window.MonacoEnvironment !== 'undefined' || document.querySelector('.monaco-workbench')) {
            console.log('VS Code loaded, applying optimizations...');
            
            // Mobile layout optimizations
            const style = document.createElement('style');
            style.textContent = `
              /* Full interface visibility */
              .part.titlebar { display: flex !important; }
              .part.activitybar { display: flex !important; min-width: 48px !important; }
              .part.sidebar { display: flex !important; min-width: 200px !important; }
              .part.editor { display: flex !important; flex: 1 !important; }
              .part.panel { display: flex !important; }
              .part.statusbar { display: flex !important; }
              
              /* Mobile-friendly sizing */
              .monaco-workbench { font-size: 16px !important; }
              .monaco-editor { font-size: 16px !important; line-height: 1.6 !important; }
              .monaco-editor .margin { font-size: 14px !important; }
              .monaco-list-row { min-height: 32px !important; }
              .action-label { padding: 8px !important; }
              
              /* Improve touch targets */
              .monaco-button { min-height: 36px !important; padding: 8px 16px !important; }
              .monaco-inputbox { min-height: 36px !important; }
              .tab { min-height: 36px !important; padding: 8px 12px !important; }
              
              /* Scrollbar optimization for mobile */
              .monaco-scrollable-element .scrollbar { 
                width: 14px !important; 
                height: 14px !important;
              }
              
              /* File explorer optimization */
              .explorer-viewlet .monaco-list-row { 
                padding: 4px 8px !important; 
                min-height: 28px !important; 
              }
              
              /* Terminal optimization */
              .terminal-wrapper { font-size: 14px !important; }
              
              /* Status bar optimization */
              .statusbar-item { padding: 4px 8px !important; }
            `;
            document.head.appendChild(style);
            
            // Enable file system access features
            try {
              // Try to enable web file system access if available
              if ('showDirectoryPicker' in window) {
                console.log('File System Access API available');
                
                // Add custom file access button to VS Code
                const activityBar = document.querySelector('.part.activitybar .content');
                if (activityBar) {
                  const fileButton = document.createElement('div');
                  fileButton.className = 'monaco-action-bar';
                  fileButton.innerHTML = `
                    <div class="action-item" title="Open Local Files">
                      <a class="action-label" onclick="openLocalFiles()">
                        <span class="codicon codicon-folder-opened"></span>
                      </a>
                    </div>
                  `;
                  activityBar.appendChild(fileButton);
                }
                
                // Add global function for file access
                window.openLocalFiles = async function() {
                  try {
                    const dirHandle = await window.showDirectoryPicker();
                    console.log('Directory selected:', dirHandle.name);
                    
                    // Try to integrate with VS Code workspace
                    if (window.vscode && window.vscode.workspace) {
                      // This would require VS Code web extensions
                      console.log('Opening directory in VS Code workspace');
                    }
                  } catch (err) {
                    console.error('File access error:', err);
                  }
                };
              } else {
                console.log('File System Access API not available');
                
                // Fallback: Add file input for file uploads
                const fileInput = document.createElement('input');
                fileInput.type = 'file';
                fileInput.multiple = true;
                fileInput.style.display = 'none';
                fileInput.setAttribute('webkitdirectory', '');
                fileInput.addEventListener('change', function(e) {
                  const files = Array.from(e.target.files);
                  console.log('Files selected:', files.length);
                  
                  // Create virtual file system in VS Code
                  files.forEach(file => {
                    const reader = new FileReader();
                    reader.onload = function(e) {
                      console.log('File loaded:', file.name);
                      // This would require VS Code extension integration
                    };
                    reader.readAsText(file);
                  });
                });
                document.body.appendChild(fileInput);
                
                // Add button to trigger file input
                const activityBar = document.querySelector('.part.activitybar .content');
                if (activityBar) {
                  const fileButton = document.createElement('div');
                  fileButton.className = 'monaco-action-bar';
                  fileButton.innerHTML = `
                    <div class="action-item" title="Upload Files">
                      <a class="action-label" onclick="document.querySelector('input[type=file]').click()">
                        <span class="codicon codicon-cloud-upload"></span>
                      </a>
                    </div>
                  `;
                  activityBar.appendChild(fileButton);
                }
              }
            } catch (err) {
              console.error('File system setup error:', err);
            }
            
            // Improve mobile touch handling
            document.addEventListener('touchstart', function(e) {
              // Prevent zoom on double tap for specific elements
              if (e.target.closest('.monaco-editor, .monaco-list')) {
                let lastTouchEnd = 0;
                const now = (new Date()).getTime();
                if (now - lastTouchEnd <= 300) {
                  e.preventDefault();
                }
                lastTouchEnd = now;
              }
            });
            
            console.log('VS Code mobile optimizations completed');
          } else {
            // VS Code not ready yet, try again
            setTimeout(waitForVSCode, 500);
          }
        }
        
        // Start optimization process
        waitForVSCode();
      ''');
    }
  }

  void _showWebViewError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WebView Error: $message'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open in Browser',
            onPressed: _openInBrowser,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));
      widget.onSync?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Synced with Buddy App successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Sync failed: $e')));
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Platform-specific routing: Mobile uses Buddy Editor, Desktop uses VS Code
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Mobile: Use Buddy Code Editor
      return _buildBuddyCodeEditor(context);
    } else {
      // Desktop/Web: Use VS Code WebView
      return _buildVSCodeInterface(context);
    }
  }

  Widget _buildBuddyCodeEditor(BuildContext context) {
    // Convert ProjectFlow to ProjectModel for Buddy Code Editor
    final projectModel = ProjectModel(
      name: widget.project.title,
      path:
          '/data/data/com.example.buddy_app/files/projects/${widget.project.title}', // Android app-specific path
      description: widget.project.description,
      projectType: 'buddy_flow',
    );

    // Create the project directory if it doesn't exist
    return FutureBuilder(
      future: _ensureProjectDirectory(projectModel.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF1a1a1a),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF007acc)),
                  SizedBox(height: 16),
                  Text(
                    'Initializing Buddy Code Editor...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        return BuddyCodeEditorScreen(project: projectModel);
      },
    );
  }

  Future<void> _ensureProjectDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);

        // Create a sample file to get started
        final sampleFile = File('$path/main.dart');
        await sampleFile.writeAsString('''
// Welcome to Buddy Code Editor!
// This is a sample Dart file to get you started.

void main() {
  print('Hello from Buddy Code Editor!');
  print('Project: ${widget.project.title}');
}

class BuddyProject {
  final String name;
  final String description;
  
  BuddyProject({
    required this.name,
    required this.description,
  });
  
  void start() {
    print('Starting project: \$name');
    print('Description: \$description');
  }
}
''');
      }
    } catch (e) {
      print('Error creating project directory: $e');
    }
  }

  Widget _buildVSCodeInterface(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey[900]!, Colors.grey[850]!],
                ),
              ),
            ),

            // VS Code Window
            _buildVSCodeWindow(),

            // Window Controls
            if (!_isFullScreen) _buildWindowControls(),

            // Loading Overlay
            if (_isLaunching) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVSCodeWindow() {
    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isFullScreen ? 1.0 : _windowScale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1e1e1e),
              borderRadius: _isFullScreen
                  ? BorderRadius.zero
                  : BorderRadius.circular(16),
              boxShadow: _isFullScreen
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF007acc).withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
              border: _isFullScreen
                  ? null
                  : Border.all(
                      color: const Color(0xFF007acc).withOpacity(0.3),
                      width: 1,
                    ),
            ),
            child: ClipRRect(
              borderRadius: _isFullScreen
                  ? BorderRadius.zero
                  : BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildWindowTitleBar(),
                  Expanded(child: _buildVSCodeContent()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWindowTitleBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1e1e1e),
        border: Border(bottom: BorderSide(color: Colors.grey[700]!, width: 1)),
      ),
      child: Row(
        children: [
          // Window Controls (macOS style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildWindowControlButton(
                  Colors.red[400]!,
                  Icons.close,
                  () => widget.onClose?.call(),
                ),
                const SizedBox(width: 8),
                _buildWindowControlButton(
                  Colors.yellow[600]!,
                  Icons.minimize,
                  _toggleMinimize,
                ),
                const SizedBox(width: 8),
                _buildWindowControlButton(
                  Colors.green[400]!,
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  _toggleFullScreen,
                ),
              ],
            ),
          ),

          // Title
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.code, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.project.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            children: [
              _buildActionButton(Icons.folder_open, 'Files', _openFileManager),
              _buildActionButton(Icons.refresh, 'Refresh', _refreshWebView),
              _buildActionButton(
                Icons.sync,
                'Sync',
                _isSyncing ? null : _triggerSync,
                isLoading: _isSyncing,
              ),
              _buildActionButton(
                Icons.open_in_browser,
                'External',
                _openInBrowser,
              ),
              _buildActionButton(Icons.settings, 'Settings', _showSettings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWindowControlButton(
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 8, color: Colors.white.withOpacity(0.7)),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    bool isLoading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildVSCodeContent() {
    return Container(
      color: const Color(0xFF1e1e1e),
      child: Stack(
        children: [
          // Platform-specific content
          if (kIsWeb)
            _buildWebFallback()
          else if (_webViewController != null)
            // WebView with VS Code for mobile platforms - ensure full interface
            Container(
              width: double.infinity,
              height: double.infinity,
              child: WebViewWidget(controller: _webViewController!),
            )
          else
            // Fallback when WebView is not available
            _buildWebViewUnavailableFallback(),

          // Loading overlay with progress
          if (_isWebViewLoading && !kIsWeb && _webViewController != null)
            Container(
              color: const Color(0xFF1e1e1e).withValues(alpha: 0.95),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // VS Code Logo with animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1000),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007acc),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007acc).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.code,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Loading progress with better styling
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: LinearProgressIndicator(
                              value: _loadingProgress,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF007acc),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(_loadingProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _getLoadingStage(),
                                style: const TextStyle(
                                  color: Color(0xFF007acc),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Loading VS Code...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getLoadingMessage(),
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Cancel button with better styling
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[600]!),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebFallback() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web, size: 80, color: const Color(0xFF007acc)),
            const SizedBox(height: 24),
            const Text(
              'VS Code Online',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Project: ${widget.project.title}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            const Text(
              'WebView is not available on this platform.\nClick below to open VS Code in your browser.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open VS Code in Browser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007acc),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewUnavailableFallback() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'WebView Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Project: ${widget.project.title}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            const Text(
              'WebView could not be initialized on this device.\nThis might be due to a missing WebView implementation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open VS Code in Browser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowControls() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlButton(
              Icons.remove,
              'Zoom Out',
              _windowScale > 0.5 ? _zoomOut : null,
            ),
            _buildControlButton(Icons.aspect_ratio, 'Reset Size', _resetZoom),
            _buildControlButton(
              Icons.add,
              'Zoom In',
              _windowScale < 1.5 ? _zoomIn : null,
            ),
            _buildControlButton(
              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              _isFullScreen ? 'Exit Full Screen' : 'Full Screen',
              _toggleFullScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF007acc)),
            SizedBox(height: 16),
            Text(
              'Loading VS Code...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  // Control Methods
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  void _toggleMinimize() {
    _opacityController.animateTo(_opacityController.value == 1.0 ? 0.3 : 1.0);
  }

  void _zoomIn() {
    setState(() {
      _windowScale = (_windowScale + 0.1).clamp(0.5, 1.5);
    });
    _scaleController.animateTo(_windowScale);
  }

  void _zoomOut() {
    setState(() {
      _windowScale = (_windowScale - 0.1).clamp(0.5, 1.5);
    });
    _scaleController.animateTo(_windowScale);
  }

  void _resetZoom() {
    setState(() {
      _windowScale = 1.0;
    });
    _scaleController.animateTo(1.0);
  }

  void _openInBrowser() async {
    final url = widget.session.vscodeUrl ?? 'https://vscode.dev';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _refreshWebView() {
    _webViewController?.reload();
    setState(() {
      _isWebViewLoading = true;
      _loadingProgress = 0.0;
    });
  }

  String _getLoadingMessage() {
    if (_loadingProgress < 0.3) {
      return 'Initializing VS Code environment...';
    } else if (_loadingProgress < 0.7) {
      return 'Loading editor components...';
    } else if (_loadingProgress < 0.9) {
      return 'Setting up workspace...';
    } else {
      return 'Almost ready!';
    }
  }

  String _getLoadingStage() {
    if (_loadingProgress < 0.2) {
      return 'Connecting...';
    } else if (_loadingProgress < 0.5) {
      return 'Loading...';
    } else if (_loadingProgress < 0.8) {
      return 'Preparing...';
    } else {
      return 'Finalizing...';
    }
  }

  Future<void> _openFileManager() async {
    try {
      // Request storage permissions
      var permission = await Permission.storage.request();
      if (permission.isDenied) {
        permission = await Permission.manageExternalStorage.request();
      }

      if (permission.isGranted || permission.isLimited) {
        // Show file access instructions
        _showFileAccessDialog();
      } else {
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      debugPrint('File manager error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFileAccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To work with files in VS Code:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('1. Use the Explorer panel in VS Code'),
            const Text('2. Open folders via the File menu'),
            const Text('3. Connect to GitHub repositories'),
            const Text('4. Use the terminal for file operations'),
            const SizedBox(height: 16),
            const Text(
              'For local files, VS Code web has limited access. Consider using the desktop version for full file system access.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _injectFileSystemHelpers();
            },
            child: const Text('Enable Helpers'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _injectFileSystemHelpers() {
    if (_webViewController != null) {
      _webViewController!.runJavaScript('''
        // Add file system helper functions to VS Code
        (function() {
          // Create a helper panel
          const helper = document.createElement('div');
          helper.id = 'file-helper';
          helper.style.cssText = `
            position: fixed;
            top: 50px;
            right: 10px;
            background: #2d2d30;
            border: 1px solid #464647;
            border-radius: 6px;
            padding: 12px;
            z-index: 1000;
            max-width: 250px;
            font-family: 'Segoe UI', sans-serif;
            font-size: 12px;
            color: #cccccc;
          `;
          
          helper.innerHTML = `
            <div style="font-weight: bold; margin-bottom: 8px;">📁 File Access Tips</div>
            <div style="margin-bottom: 4px;">• Use Ctrl+O to open files</div>
            <div style="margin-bottom: 4px;">• Use Ctrl+K Ctrl+O to open folders</div>
            <div style="margin-bottom: 4px;">• Drag & drop files into editor</div>
            <div style="margin-bottom: 8px;">• Use File > Open... menu</div>
            <button onclick="this.parentElement.remove()" style="
              background: #0e639c;
              border: none;
              color: white;
              padding: 4px 8px;
              border-radius: 3px;
              cursor: pointer;
              font-size: 11px;
            ">Close</button>
          `;
          
          document.body.appendChild(helper);
          
          // Auto-remove after 10 seconds
          setTimeout(() => {
            if (helper.parentElement) {
              helper.remove();
            }
          }, 10000);
          
          console.log('File system helpers activated');
        })();
      ''');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File access helpers enabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'File access permission is required to open files in VS Code. '
          'Please grant permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VS Code Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme'),
                subtitle: const Text('Dark (VS Code)'),
                onTap: () => _toggleTheme(),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Font Size'),
                subtitle: const Text('Adjust editor font size'),
                onTap: () => _adjustFontSize(),
              ),
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Performance Mode'),
                subtitle: const Text('Optimize for mobile'),
                trailing: Switch(
                  value: true,
                  onChanged: (v) => _togglePerformanceMode(v),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh WebView'),
                subtitle: const Text('Reload VS Code interface'),
                onTap: () {
                  Navigator.pop(context);
                  _refreshWebView();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: const Text('Clear Cache'),
                subtitle: const Text('Reset WebView cache'),
                onTap: () => _clearWebViewCache(),
              ),
              ListTile(
                leading: const Icon(Icons.fullscreen),
                title: const Text('Fullscreen Mode'),
                subtitle: const Text('Toggle window mode'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFullScreen();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleTheme() {
    if (_webViewController != null) {
      _webViewController!.runJavaScript('''
        // Toggle between dark and light theme
        const currentTheme = document.body.classList.contains('vscode-light') ? 'dark' : 'light';
        window.location.search = window.location.search.replace(/theme=[^&]*/, '') + '&theme=' + currentTheme;
      ''');
    }
  }

  void _adjustFontSize() {
    if (_webViewController != null) {
      _webViewController!.runJavaScript('''
        // Increase font size for better mobile readability
        const style = document.createElement('style');
        style.textContent = `
          .monaco-editor { font-size: 16px !important; line-height: 1.5 !important; }
          .monaco-editor .margin { font-size: 14px !important; }
        `;
        document.head.appendChild(style);
      ''');
    }
    Navigator.pop(context);
  }

  void _togglePerformanceMode(bool enabled) {
    if (_webViewController != null) {
      _webViewController!.runJavaScript('''
        // Apply performance optimizations
        if ($enabled) {
          // Disable animations and transitions
          const style = document.createElement('style');
          style.textContent = `
            * { transition: none !important; animation: none !important; }
            .monaco-scrollable-element .scrollbar { display: none; }
            .minimap { display: none !important; }
            .monaco-editor .margin-view-overlays { display: none; }
          `;
          style.id = 'performance-mode';
          document.head.appendChild(style);
        } else {
          const perfStyle = document.getElementById('performance-mode');
          if (perfStyle) perfStyle.remove();
        }
      ''');
    }
  }

  void _clearWebViewCache() {
    if (_webViewController != null) {
      _webViewController!.runJavaScript('''
        // Clear cache and reload
        if ('caches' in window) {
          caches.keys().then(names => {
            names.forEach(name => caches.delete(name));
          });
        }
        localStorage.clear();
        sessionStorage.clear();
        location.reload();
      ''');
    }
    Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared, reloading...'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }
}
