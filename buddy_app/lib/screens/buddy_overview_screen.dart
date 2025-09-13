// lib/screens/buddy_overview_screen.dart
import 'package:flutter/material.dart';
import 'dock/dock_screen.dart';
import 'buddy_code_editor/editor_selector.dart';
import '../models/flow_models.dart';

class BuddyOverviewScreen extends StatelessWidget {
  const BuddyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Buddy Ecosystem',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue, Colors.purple, Colors.teal],
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.developer_mode, size: 80, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Complete Development Ecosystem',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeSection(context),
                  const SizedBox(height: 24),

                  // Core Features
                  _buildCoreFeatures(context),
                  const SizedBox(height: 24),

                  // Quick Start
                  _buildQuickStart(context),
                  const SizedBox(height: 24),

                  // Technical Details
                  _buildTechnicalDetails(context),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.waving_hand, color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Welcome to Buddy!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Buddy is a comprehensive cross-platform development ecosystem that brings together device management, terminal automation, and a full-featured code editor with real-time VS Code synchronization.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFeatureChip('📱 Device Management', Colors.blue),
                _buildFeatureChip('💻 Code Editor', Colors.green),
                _buildFeatureChip('🔄 Real-time Sync', Colors.purple),
                _buildFeatureChip('🤖 Automation', Colors.orange),
                _buildFeatureChip('🌐 Cross-platform', Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildCoreFeatures(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Core Features',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Feature Cards Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildFeatureCard(
              icon: Icons.devices,
              title: 'Device Dock',
              description:
                  'Manage multiple devices, execute commands remotely, monitor system resources',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DockScreen()),
              ),
            ),
            _buildFeatureCard(
              icon: Icons.code,
              title: 'VS Code Integration',
              description:
                  'Open projects in VS Code with seamless sync across all devices',
              color: Colors.green,
              onTap: () => _openVSCodeIntegration(context),
            ),
            _buildFeatureCard(
              icon: Icons.sync,
              title: 'VS Code Sync',
              description:
                  'Real-time synchronization with VS Code for seamless development',
              color: Colors.purple,
              onTap: () => _showVSCodeSyncInfo(context),
            ),
            _buildFeatureCard(
              icon: Icons.terminal,
              title: 'Automation',
              description:
                  'Powerful terminal with automation commands and workflow management',
              color: Colors.orange,
              onTap: () => _showAutomationInfo(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStart(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Quick Start Guide',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildQuickStartStep(
              '1',
              'Device Management',
              'Register your current device and discover network devices',
              Icons.smartphone,
              Colors.blue,
            ),
            _buildQuickStartStep(
              '2',
              'Create Project',
              'Choose from Flutter, Python, Node.js, or Android templates',
              Icons.create_new_folder,
              Colors.green,
            ),
            _buildQuickStartStep(
              '3',
              'Start Coding',
              'Use the built-in editor with syntax highlighting and auto-completion',
              Icons.code,
              Colors.purple,
            ),
            _buildQuickStartStep(
              '4',
              'Sync & Deploy',
              'Sync with VS Code and deploy to connected devices',
              Icons.sync_alt,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartStep(
    String step,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetails(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.engineering, color: Colors.teal, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Technical Architecture',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTechSection('Frontend', [
              '• Flutter cross-platform framework',
              '• Material Design 3 components',
              '• Real-time WebSocket connections',
              '• Responsive UI for mobile and desktop',
            ]),

            _buildTechSection('Backend', [
              '• FastAPI with async/await support',
              '• WebSocket for real-time communication',
              '• SQLite database with SQLAlchemy ORM',
              '• RESTful APIs for all operations',
            ]),

            _buildTechSection('Code Editor Features', [
              '• Syntax highlighting for 10+ languages',
              '• Project templates and scaffolding',
              '• Integrated build and test systems',
              '• Git integration and version control',
              '• Real-time VS Code synchronization',
            ]),

            _buildTechSection('Device Management', [
              '• Cross-platform device detection',
              '• Remote command execution',
              '• System resource monitoring',
              '• Network device discovery',
              '• Terminal automation workflows',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildTechSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(item, style: const TextStyle(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DockScreen()),
                ),
                icon: const Icon(Icons.devices),
                label: const Text('Open Device Dock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openVSCodeIntegration(context),
                icon: const Icon(Icons.code),
                label: const Text('Start Coding'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showAdvancedFeatures(context),
          icon: const Icon(Icons.explore),
          label: const Text('Explore Advanced Features'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  void _showVSCodeSyncInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync, color: Colors.purple),
            SizedBox(width: 8),
            Text('VS Code Synchronization'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Real-time Synchronization Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Automatic file synchronization'),
              Text('• Project state sharing'),
              Text('• Extension synchronization'),
              Text('• Settings synchronization'),
              Text('• Live collaboration support'),
              SizedBox(height: 16),
              Text(
                'To enable VS Code sync:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Install Buddy VS Code extension'),
              Text('2. Connect to the same network'),
              Text('3. Enable sync in settings'),
              Text('4. Start coding seamlessly!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open VS Code sync setup
            },
            child: const Text('Setup Sync'),
          ),
        ],
      ),
    );
  }

  void _showAutomationInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.autorenew, color: Colors.orange),
            SizedBox(width: 8),
            Text('Automation Features'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Terminal Automation:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Pre-built command workflows'),
              Text('• Git operations automation'),
              Text('• Build and deployment scripts'),
              Text('• System monitoring commands'),
              Text('• Custom macro creation'),
              SizedBox(height: 16),
              Text(
                'Development Automation:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Flutter hot reload'),
              Text('• Automatic testing'),
              Text('• Code formatting'),
              Text('• Dependency management'),
              Text('• Release automation'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DockScreen()),
              );
            },
            child: const Text('Try Automation'),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFeatures(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Advanced Features'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🚀 Project Features:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Multi-platform project templates'),
              Text('• Integrated build systems'),
              Text('• Automated testing frameworks'),
              Text('• Git version control'),
              Text('• Code snippets library'),
              SizedBox(height: 16),
              Text(
                '🌐 Collaboration:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Real-time code collaboration'),
              Text('• Shared project workspaces'),
              Text('• Live cursor tracking'),
              Text('• Comment and review system'),
              SizedBox(height: 16),
              Text(
                '🔧 DevOps Integration:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• CI/CD pipeline integration'),
              Text('• Container deployment'),
              Text('• Cloud sync and backup'),
              Text('• Performance monitoring'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Amazing!'),
          ),
        ],
      ),
    );
  }

  void _openVSCodeIntegration(BuildContext context) {
    // Create a basic VS Code session
    final basicFlow = ProjectFlow(
      id: 'overview_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Welcome to VS Code',
      description: 'Start your coding journey with VS Code integration',
      estimatedDuration: '1 hour',
      difficulty: FlowDifficulty.easy,
      checkpoints: [],
      tags: ['vscode', 'welcome'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorSelector(projectFlow: basicFlow),
      ),
    );
  }
}
