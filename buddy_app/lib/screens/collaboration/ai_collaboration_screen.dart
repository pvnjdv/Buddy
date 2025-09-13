import 'package:flutter/material.dart';
import '../../models/collaboration_models.dart';
import '../../models/flow_models.dart';
import '../../services/collaboration/ai_collaboration_service.dart';
import '../../config/settings/theme_config.dart';
import 'invitation_management_screen.dart';

class AICollaborationScreen extends StatefulWidget {
  final ProjectFlow project;

  const AICollaborationScreen({super.key, required this.project});

  @override
  State<AICollaborationScreen> createState() => _AICollaborationScreenState();
}

class _AICollaborationScreenState extends State<AICollaborationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<AICollaborationInsight> _insights = [];
  ProjectAnalysis? _analysis;
  List<CollaborationInvitation> _invitations = [];
  bool _isLoading = true;
  bool _isGeneratingInsights = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final futures = await Future.wait([
        AICollaborationService.getAIInsights(widget.project.id.hashCode),
        AICollaborationService.analyzeProjectProgress(
          widget.project.id.hashCode,
        ),
        AICollaborationService.getMyInvitations(),
      ]);

      setState(() {
        _insights = futures[0] as List<AICollaborationInsight>;
        _analysis = futures[1] as ProjectAnalysis;
        _invitations = futures[2] as List<CollaborationInvitation>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _generateNewInsights() async {
    setState(() => _isGeneratingInsights = true);

    try {
      final success = await AICollaborationService.generateAIInsights(
        widget.project.id.hashCode,
      );

      if (success) {
        // Reload insights after generation
        await Future.delayed(const Duration(seconds: 3)); // Wait for processing
        final newInsights = await AICollaborationService.getAIInsights(
          widget.project.id.hashCode,
        );

        setState(() {
          _insights = newInsights;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New AI insights generated!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating insights: $e')));
    } finally {
      setState(() => _isGeneratingInsights = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Collaboration - ${widget.project.title}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.insights), text: 'Insights'),
            Tab(icon: Icon(Icons.analytics), text: 'Analysis'),
            Tab(icon: Icon(Icons.group_add), text: 'Collaborate'),
            Tab(icon: Icon(Icons.mail), text: 'Invitations'),
          ],
        ),
        actions: [
          IconButton(
            icon: _isGeneratingInsights
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            onPressed: _isGeneratingInsights ? null : _generateNewInsights,
            tooltip: 'Generate AI Insights',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInsightsTab(),
                _buildAnalysisTab(),
                _buildCollaborationTab(),
                _buildInvitationsTab(),
              ],
            ),
    );
  }

  Widget _buildInsightsTab() {
    if (_insights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No AI insights available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate insights to get AI-powered recommendations',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateNewInsights,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Insights'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _insights.length,
      itemBuilder: (context, index) {
        final insight = _insights[index];
        return _buildInsightCard(insight);
      },
    );
  }

  Widget _buildInsightCard(AICollaborationInsight insight) {
    IconData iconData;
    Color iconColor;

    switch (insight.insightType) {
      case 'progress':
        iconData = Icons.trending_up;
        iconColor = Colors.blue;
        break;
      case 'suggestion':
        iconData = Icons.lightbulb;
        iconColor = Colors.orange;
        break;
      case 'blocker':
        iconData = Icons.warning;
        iconColor = Colors.red;
        break;
      case 'collaboration':
        iconData = Icons.people;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.info;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${insight.relevanceScore}%',
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(insight.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Implement insight details or actions
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_analysis == null) {
      return const Center(child: Text('No analysis data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressCard(),
          const SizedBox(height: 16),
          _buildContributorsCard(),
          const SizedBox(height: 16),
          _buildBlockersCard(),
          const SizedBox(height: 16),
          _buildSuggestionsCard(),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _analysis!.overallProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _analysis!.overallProgress > 75
                    ? Colors.green
                    : _analysis!.overallProgress > 50
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_analysis!.overallProgress.toStringAsFixed(1)}% Complete',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${_analysis!.completedCheckpoints}/${_analysis!.totalCheckpoints} Checkpoints',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Estimated Completion: ${_formatDateTime(_analysis!.estimatedCompletion)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributorsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Contributions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._analysis!.collaboratorContributions.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: entry.value / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.value.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Potential Blockers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_analysis!.blockers.isEmpty)
              Text(
                'No blockers identified 🎉',
                style: TextStyle(color: Colors.green[600]),
              )
            else
              ..._analysis!.blockers.map(
                (blocker) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(blocker)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Suggestions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._analysis!.suggestions.map(
              (suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(suggestion)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollaborationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCreateCollaborationCard(),
          const SizedBox(height: 24),
          _buildInviteTeamMembersCard(),
          const SizedBox(height: 24),
          _buildCollaborationFeaturesCard(),
        ],
      ),
    );
  }

  Widget _buildCreateCollaborationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start Collaboration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a collaborative workspace for your team to work together on this project.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _createCollaboration(),
                icon: const Icon(Icons.group_add),
                label: const Text('Create Collaboration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteTeamMembersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite Team Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add team members by their mobile number to collaborate on this project.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showInviteDialog(),
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Members'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollaborationFeaturesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collaboration Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              Icons.sync,
              'Real-time Sync',
              'Changes sync instantly across all team members',
            ),
            _buildFeatureItem(
              Icons.chat,
              'Team Chat',
              'Built-in messaging for project discussions',
            ),
            _buildFeatureItem(
              Icons.assignment_turned_in,
              'Task Assignment',
              'Assign checkpoints to specific team members',
            ),
            _buildFeatureItem(
              Icons.analytics,
              'Progress Tracking',
              'AI-powered insights on team performance',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsTab() {
    return InvitationManagementScreen(
      invitations: _invitations,
      onInvitationResponse: (invitation, accepted) async {
        final success = await AICollaborationService.respondToInvitation(
          invitation.id,
          accepted,
        );

        if (success) {
          setState(() {
            _invitations.removeWhere((inv) => inv.id == invitation.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                accepted ? 'Invitation accepted!' : 'Invitation declined',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _createCollaboration() async {
    // TODO: Implement collaboration creation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collaboration creation coming soon!')),
    );
  }

  Future<void> _showInviteDialog() async {
    // TODO: Implement invite dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite functionality coming soon!')),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
