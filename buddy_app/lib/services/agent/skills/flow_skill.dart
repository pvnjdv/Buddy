import '../../flow_service.dart';
import '../buddy_orchestrator.dart';

class FlowSkill {
  bool matches(String prompt) {
    final p = prompt.toLowerCase();
    return p.contains('new flow') ||
        p.contains('create flow') ||
        p.startsWith('plan ');
  }

  Future<AgentResult> execute(String prompt) async {
    final flow = await FlowService.generateFlowFromDescription(prompt);
    return AgentResult(
      handled: true,
      message: 'Created a flow for: $prompt',
      flow: flow,
      extra: {'action': 'create_flow'},
    );
  }
}
