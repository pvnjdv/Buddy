/// Enhanced AI thinking service providing GPT-5 level reasoning and analysis
class AIThinkingService {
  /// Analyze user intent with advanced reasoning
  static Map<String, dynamic> analyzeIntent(String prompt) {
    final p = prompt.toLowerCase().trim();
    final words = p.split(RegExp(r'\s+'));
    final sentences = p
        .split(RegExp(r'[.!?]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Multi-layered intent analysis
    final analysis = <String, dynamic>{
      'raw_prompt': prompt,
      'processed_text': p,
      'word_count': words.length,
      'sentence_count': sentences.length,
      'complexity_score': _calculateComplexity(p, words, sentences),
    };

    // Intent classification with confidence scoring
    final intents = <String, double>{};

    // Primary intent categories with weighted scoring
    _analyzeFlowCreationIntent(p, words, intents);
    _analyzeSystemControlIntent(p, words, intents);
    _analyzeGitHubIntent(p, words, intents);
    _analyzeNavigationIntent(p, words, intents);
    _analyzeCommunicationIntent(p, words, intents);
    _analyzeTaskManagementIntent(p, words, intents);
    _analyzeInformationRetrievalIntent(p, words, intents);
    _analyzeAutomationIntent(p, words, intents);

    // Multi-intent detection (user might want multiple things)
    final multiIntents = intents.entries.where((e) => e.value > 0.5).toList();

    // Primary intent is highest scoring
    final primaryIntent = intents.entries.isNotEmpty
        ? intents.entries.reduce((a, b) => a.value > b.value ? a : b)
        : const MapEntry('unknown', 0.0);

    // Context and sentiment analysis
    final context = _analyzeContext(p, words, sentences);
    final sentiment = _analyzeSentiment(p, words);
    final urgency = _analyzeUrgency(p, words);

    // Reasoning chain
    final reasoning = _generateReasoningChain(p, intents, context, sentiment);

    analysis.addAll({
      'primary_intent': primaryIntent.key,
      'primary_confidence': primaryIntent.value,
      'all_intents': intents,
      'multi_intents': multiIntents
          .map((e) => {'intent': e.key, 'confidence': e.value})
          .toList(),
      'context': context,
      'sentiment': sentiment,
      'urgency': urgency,
      'reasoning_chain': reasoning,
      'processing_strategy': _determineProcessingStrategy(
        primaryIntent,
        context,
        urgency,
      ),
    });

    return analysis;
  }

  /// Generate optimized response strategy based on analysis
  static Map<String, dynamic> generateResponseStrategy(
    Map<String, dynamic> intentAnalysis,
  ) {
    final primaryIntent = intentAnalysis['primary_intent'] as String;
    final confidence = intentAnalysis['primary_confidence'] as double;
    final context = intentAnalysis['context'] as Map<String, dynamic>;
    final urgency = intentAnalysis['urgency'] as Map<String, dynamic>;

    final strategy = <String, dynamic>{
      'response_type': _determineResponseType(primaryIntent, confidence),
      'execution_priority': _calculateExecutionPriority(urgency, confidence),
      'multi_step_required': intentAnalysis['complexity_score'] > 7.0,
      'confirmation_needed': _needsConfirmation(primaryIntent, urgency),
      'estimated_duration': _estimateDuration(primaryIntent, context),
    };

    // Generate step-by-step execution plan
    strategy['execution_plan'] = _generateExecutionPlan(intentAnalysis);

    // Determine if background processing is needed
    strategy['background_processing'] = _needsBackgroundProcessing(
      primaryIntent,
    );

    // Risk assessment
    strategy['risk_assessment'] = _assessRisks(primaryIntent, context);

    return strategy;
  }

  /// Generate human-like reasoning chain
  static List<String> _generateReasoningChain(
    String prompt,
    Map<String, double> intents,
    Map<String, dynamic> context,
    Map<String, dynamic> sentiment,
  ) {
    final reasoning = <String>[];

    // Step 1: Understanding
    reasoning.add(
      '🧠 Analyzing user request: "${prompt.length > 50 ? '${prompt.substring(0, 50)}...' : prompt}"',
    );

    // Step 2: Intent recognition
    final topIntents = intents.entries.where((e) => e.value > 0.3).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (topIntents.isNotEmpty) {
      reasoning.add(
        '🎯 Detected intent: ${topIntents.first.key} (${(topIntents.first.value * 100).toInt()}% confidence)',
      );

      if (topIntents.length > 1) {
        reasoning.add(
          '🔄 Secondary intents: ${topIntents.skip(1).take(2).map((e) => '${e.key} (${(e.value * 100).toInt()}%)').join(', ')}',
        );
      }
    }

    // Step 3: Context analysis
    if (context['complexity'] > 5) {
      reasoning.add(
        '⚙️ Complex request detected - breaking down into manageable steps',
      );
    }

    // Step 4: Sentiment consideration
    if (sentiment['urgency'] > 0.7) {
      reasoning.add('⚡ High urgency detected - prioritizing immediate action');
    } else if (sentiment['politeness'] > 0.8) {
      reasoning.add(
        '😊 Polite request - ensuring thorough and helpful response',
      );
    }

    // Step 5: Action planning
    reasoning.add('📋 Planning optimal execution strategy...');

    return reasoning;
  }

  /// Advanced complexity calculation
  static double _calculateComplexity(
    String text,
    List<String> words,
    List<String> sentences,
  ) {
    var complexity = 0.0;

    // Length factors
    complexity += words.length * 0.1;
    complexity += sentences.length * 0.5;

    // Technical terms
    final technicalTerms = [
      'git',
      'github',
      'system',
      'process',
      'flow',
      'api',
      'database',
      'server',
    ];
    complexity += words.where((w) => technicalTerms.contains(w)).length * 0.3;

    // Conditional/complex structures
    final complexWords = [
      'if',
      'when',
      'while',
      'unless',
      'however',
      'although',
      'because',
    ];
    complexity += words.where((w) => complexWords.contains(w)).length * 0.5;

    // Questions vs commands
    if (text.contains('?')) complexity += 0.5;
    if (text.contains('how')) complexity += 0.3;
    if (text.contains('why')) complexity += 0.4;

    return complexity.clamp(0.0, 10.0);
  }

  /// Analyze specific intent categories
  static void _analyzeFlowCreationIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    // Direct keywords
    final flowKeywords = {
      'flow': 0.8,
      'project': 0.6,
      'plan': 0.5,
      'workflow': 0.7,
      'timeline': 0.6,
      'schedule': 0.4,
    };
    for (final entry in flowKeywords.entries) {
      if (words.contains(entry.key)) score += entry.value;
    }

    // Action words
    final actionWords = {'create', 'generate', 'build', 'make', 'design'};
    if (words.any((w) => actionWords.contains(w))) score += 0.3;

    // Context clues
    if (text.contains('notes and all')) score += 0.4;
    if (text.contains('alarm') && text.contains('reminder')) score += 0.3;
    if (text.contains('meeting')) score += 0.2;

    intents['flow_creation'] = score.clamp(0.0, 1.0);
  }

  static void _analyzeSystemControlIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    final systemKeywords = {
      'system': 0.8,
      'process': 0.7,
      'kill': 0.9,
      'device': 0.6,
      'dock': 0.8,
      'monitor': 0.6,
    };
    for (final entry in systemKeywords.entries) {
      if (words.contains(entry.key)) score += entry.value;
    }

    // Command words
    final commandWords = {
      'run',
      'execute',
      'stop',
      'start',
      'control',
      'manage',
    };
    if (words.any((w) => commandWords.contains(w))) score += 0.4;

    intents['system_control'] = score.clamp(0.0, 1.0);
  }

  static void _analyzeGitHubIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    final gitKeywords = {
      'git': 0.9,
      'github': 0.9,
      'commit': 0.8,
      'push': 0.8,
      'pull': 0.8,
      'clone': 0.8,
      'repository': 0.7,
      'repo': 0.7,
    };
    for (final entry in gitKeywords.entries) {
      if (words.contains(entry.key)) score += entry.value;
    }

    // GitHub-specific actions
    if (text.contains('github copilot')) score += 0.5;
    if (text.contains('integrate') && words.contains('github')) score += 0.4;

    intents['github_operations'] = score.clamp(0.0, 1.0);
  }

  static void _analyzeNavigationIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    final navKeywords = {
      'navigate': 0.8,
      'open': 0.6,
      'show': 0.5,
      'go': 0.4,
      'display': 0.5,
      'view': 0.4,
    };
    for (final entry in navKeywords.entries) {
      if (words.contains(entry.key)) score += entry.value;
    }

    // Screen/page references
    final screens = {'screen', 'page', 'section', 'tab', 'menu'};
    if (words.any((w) => screens.contains(w))) score += 0.3;

    intents['app_navigation'] = score.clamp(0.0, 1.0);
  }

  static void _analyzeCommunicationIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    final commKeywords = {
      'message': 0.8,
      'talk': 0.8,
      'chat': 0.7,
      'call': 0.8,
      'meeting': 0.7,
      'contact': 0.6,
    };
    for (final entry in commKeywords.entries) {
      if (words.contains(entry.key)) score += entry.value;
    }

    // Communication actions
    if (text.contains('on behalf of me')) score += 0.6;
    if (text.contains('schedule meeting')) score += 0.5;

    intents['communication'] = score.clamp(0.0, 1.0);
  }

  static void _analyzeTaskManagementIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    final taskKeywords = {
      'note': 0.6,
      'reminder': 0.7,
      'alarm': 0.8,
      'schedule': 0.6,
      'task': 0.7,
      'todo': 0.8,
    };
    for (final entry in taskKeywords.entries) {
      if (words.contains(entry.key)) score += entry.value;
    }

    intents['task_management'] = score.clamp(0.0, 1.0);
  }

  static void _analyzeInformationRetrievalIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    final infoKeywords = {
      'what',
      'how',
      'why',
      'when',
      'where',
      'show',
      'tell',
      'explain',
    };
    score += words.where((w) => infoKeywords.contains(w)).length * 0.3;

    if (text.contains('?')) score += 0.4;

    intents['information_retrieval'] = score.clamp(0.0, 1.0);
  }

  static void _analyzeAutomationIntent(
    String text,
    List<String> words,
    Map<String, double> intents,
  ) {
    double score = 0.0;

    final autoKeywords = {
      'automatically': 0.8,
      'auto': 0.7,
      'automate': 0.9,
      'macro': 0.8,
    };
    for (final entry in autoKeywords.entries) {
      if (text.contains(entry.key)) score += entry.value;
    }

    intents['automation'] = score.clamp(0.0, 1.0);
  }

  /// Analyze context and environment
  static Map<String, dynamic> _analyzeContext(
    String text,
    List<String> words,
    List<String> sentences,
  ) {
    return {
      'complexity': _calculateComplexity(text, words, sentences),
      'technical_level': _calculateTechnicalLevel(words),
      'specificity': _calculateSpecificity(text, words),
      'completeness': _calculateCompleteness(text, sentences),
    };
  }

  static double _calculateTechnicalLevel(List<String> words) {
    final technicalTerms = {
      'api',
      'database',
      'server',
      'client',
      'framework',
      'library',
      'git',
      'github',
      'repository',
      'commit',
      'branch',
      'merge',
      'system',
      'process',
      'thread',
      'memory',
      'cpu',
      'kernel',
      'docker',
      'kubernetes',
      'microservice',
      'endpoint',
      'json',
      'xml',
    };

    final techCount = words.where((w) => technicalTerms.contains(w)).length;
    return (techCount / words.length * 10).clamp(0.0, 10.0);
  }

  static double _calculateSpecificity(String text, List<String> words) {
    var specificity = 0.0;

    // Specific names, numbers, paths
    if (RegExp(r'\b[A-Z][a-zA-Z]*\b').hasMatch(text))
      specificity += 2.0; // Proper nouns
    if (RegExp(r'\d+').hasMatch(text)) specificity += 1.0; // Numbers
    if (text.contains('/') || text.contains('\\')) specificity += 1.5; // Paths
    if (text.contains('.') && !text.endsWith('.'))
      specificity += 1.0; // File extensions

    return specificity.clamp(0.0, 10.0);
  }

  static double _calculateCompleteness(String text, List<String> sentences) {
    var completeness = 5.0; // Start with medium completeness

    // Questions might indicate incomplete information
    if (text.contains('?')) completeness -= 1.0;
    if (text.contains('how')) completeness -= 0.5;

    // Specificity increases completeness
    if (text.length > 100) completeness += 1.0;
    if (sentences.length > 2) completeness += 1.0;

    return completeness.clamp(0.0, 10.0);
  }

  /// Analyze sentiment and emotional context
  static Map<String, dynamic> _analyzeSentiment(
    String text,
    List<String> words,
  ) {
    final positiveWords = {
      'please',
      'thank',
      'appreciate',
      'help',
      'great',
      'awesome',
      'perfect',
    };
    final urgentWords = {
      'urgent',
      'asap',
      'quickly',
      'immediately',
      'fast',
      'now',
      'emergency',
    };
    final politeWords = {'please', 'could', 'would', 'may', 'might', 'kindly'};

    final positive = words.where((w) => positiveWords.contains(w)).length;
    final urgent = words.where((w) => urgentWords.contains(w)).length;
    final polite = words.where((w) => politeWords.contains(w)).length;

    return {
      'positivity': (positive / words.length * 10).clamp(0.0, 1.0),
      'urgency': (urgent / words.length * 20).clamp(0.0, 1.0),
      'politeness': (polite / words.length * 15).clamp(0.0, 1.0),
      'overall_tone': _determineOverallTone(positive, urgent, polite),
    };
  }

  static String _determineOverallTone(int positive, int urgent, int polite) {
    if (urgent > 0) return 'urgent';
    if (polite > positive) return 'polite';
    if (positive > 0) return 'positive';
    return 'neutral';
  }

  /// Analyze urgency levels
  static Map<String, dynamic> _analyzeUrgency(String text, List<String> words) {
    var urgencyScore = 0.0;

    final urgentIndicators = {
      'urgent': 0.9,
      'asap': 0.9,
      'immediately': 0.8,
      'now': 0.6,
      'quickly': 0.5,
      'fast': 0.4,
      'soon': 0.3,
      'emergency': 1.0,
    };

    for (final entry in urgentIndicators.entries) {
      if (words.contains(entry.key)) urgencyScore += entry.value;
    }

    // Punctuation can indicate urgency
    if (text.contains('!')) urgencyScore += 0.3;
    if (text.contains('!!')) urgencyScore += 0.5;

    return {
      'score': urgencyScore.clamp(0.0, 1.0),
      'level': _getUrgencyLevel(urgencyScore),
      'requires_immediate_action': urgencyScore > 0.7,
    };
  }

  static String _getUrgencyLevel(double score) {
    if (score >= 0.8) return 'critical';
    if (score >= 0.6) return 'high';
    if (score >= 0.4) return 'medium';
    if (score >= 0.2) return 'low';
    return 'none';
  }

  /// Determine processing strategy
  static String _determineProcessingStrategy(
    MapEntry<String, double> primaryIntent,
    Map<String, dynamic> context,
    Map<String, dynamic> urgency,
  ) {
    if (urgency['score'] > 0.7) return 'immediate_execution';
    if (context['complexity'] > 7.0) return 'step_by_step_processing';
    if (primaryIntent.value < 0.6) return 'clarification_needed';
    if (context['technical_level'] > 7.0) return 'expert_mode';

    return 'standard_processing';
  }

  /// Additional helper methods for response strategy
  static String _determineResponseType(String intent, double confidence) {
    if (confidence < 0.5) return 'clarification_request';
    if (intent == 'system_control') return 'action_with_confirmation';
    if (intent == 'github_operations') return 'technical_execution';
    if (intent == 'flow_creation') return 'creative_generation';

    return 'standard_response';
  }

  static int _calculateExecutionPriority(
    Map<String, dynamic> urgency,
    double confidence,
  ) {
    var priority = 5; // Medium priority

    if (urgency['score'] > 0.8)
      priority = 1; // Critical
    else if (urgency['score'] > 0.6)
      priority = 2; // High
    else if (urgency['score'] > 0.4)
      priority = 3; // Medium-high

    // Adjust based on confidence
    if (confidence < 0.5) priority += 2; // Lower priority if uncertain

    return priority.clamp(1, 10);
  }

  static bool _needsConfirmation(String intent, Map<String, dynamic> urgency) {
    final highRiskIntents = {'system_control', 'github_operations'};
    return highRiskIntents.contains(intent) && urgency['score'] < 0.8;
  }

  static String _estimateDuration(String intent, Map<String, dynamic> context) {
    switch (intent) {
      case 'system_control':
        return 'immediate';
      case 'github_operations':
        return '30-60 seconds';
      case 'flow_creation':
        return '1-2 minutes';
      case 'app_navigation':
        return 'immediate';
      default:
        return context['complexity'] > 5 ? '30-60 seconds' : 'immediate';
    }
  }

  static List<Map<String, dynamic>> _generateExecutionPlan(
    Map<String, dynamic> analysis,
  ) {
    final intent = analysis['primary_intent'] as String;
    final multiIntents = analysis['multi_intents'] as List;

    final plan = <Map<String, dynamic>>[];

    // Primary action
    plan.add({
      'step': 1,
      'action': intent,
      'description': _getIntentDescription(intent),
      'estimated_duration': _estimateDuration(intent, analysis['context']),
    });

    // Secondary actions for multi-intent scenarios
    for (int i = 0; i < multiIntents.length && i < 2; i++) {
      final secondaryIntent = multiIntents[i]['intent'] as String;
      if (secondaryIntent != intent) {
        plan.add({
          'step': plan.length + 1,
          'action': secondaryIntent,
          'description': _getIntentDescription(secondaryIntent),
          'estimated_duration': _estimateDuration(
            secondaryIntent,
            analysis['context'],
          ),
        });
      }
    }

    return plan;
  }

  static String _getIntentDescription(String intent) {
    switch (intent) {
      case 'flow_creation':
        return 'Create comprehensive project flow with notes, alarms, and meetings';
      case 'system_control':
        return 'Execute system operations and process management';
      case 'github_operations':
        return 'Perform Git/GitHub operations';
      case 'app_navigation':
        return 'Navigate to specific app sections';
      case 'communication':
        return 'Handle messaging and communication tasks';
      case 'task_management':
        return 'Manage notes, reminders, and tasks';
      default:
        return 'Process user request';
    }
  }

  static bool _needsBackgroundProcessing(String intent) {
    final backgroundIntents = {
      'github_operations',
      'system_control',
      'flow_creation',
    };
    return backgroundIntents.contains(intent);
  }

  static Map<String, dynamic> _assessRisks(
    String intent,
    Map<String, dynamic> context,
  ) {
    final risks = <String, dynamic>{'level': 'low', 'factors': <String>[]};

    if (intent == 'system_control') {
      risks['level'] = 'high';
      risks['factors'].add('System modification capabilities');
    }

    if (intent == 'github_operations' && context['technical_level'] > 7) {
      risks['level'] = 'medium';
      risks['factors'].add('Git repository modifications');
    }

    return risks;
  }
}
