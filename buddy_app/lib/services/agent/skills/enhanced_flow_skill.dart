import '../../flow_service.dart';
import '../../../models/flow_models.dart';
import '../buddy_orchestrator.dart';

class FlowSkill {
  bool matches(String prompt) {
    final p = prompt.toLowerCase();
    return p.contains('flow') &&
            (p.contains('create') ||
                p.contains('generate') ||
                p.contains('new') ||
                p.startsWith('plan ')) ||
        p.startsWith('create flow') ||
        p.startsWith('generate flow') ||
        p.startsWith('new flow');
  }

  Future<AgentResult> execute(String prompt) async {
    try {
      // Enhanced flow generation with integrated components
      final flow = await FlowService.generateFlowFromDescription(prompt);

      // Auto-generate related components
      final components = await _generateFlowComponents(flow, prompt);

      final message =
          '''Created comprehensive flow: "${flow.title}"
✅ ${flow.checkpoints.length} checkpoints
📝 ${components['notes_count']} notes created
⏰ ${components['alarms_count']} alarms scheduled
🤝 ${components['meetings_count']} meetings planned

Flow organized in 3 sections:
• Timelines: Project progression
• Notes: Detailed documentation
• Alarms & Meetings: Scheduled events''';

      return AgentResult(
        handled: true,
        message: message,
        flow: flow,
        extra: {
          'action': 'create_flow',
          'is_flow_created': true,
          'components': components,
          'sections': ['timelines', 'notes', 'alarms_meetings'],
        },
      );
    } catch (e) {
      return AgentResult(
        handled: true,
        message: 'Failed to create flow: $e',
        extra: {'error': e.toString()},
      );
    }
  }

  Future<Map<String, dynamic>> _generateFlowComponents(
    ProjectFlow flow,
    String originalPrompt,
  ) async {
    int notesCount = 0;
    int alarmsCount = 0;
    int meetingsCount = 0;

    try {
      // Generate notes for each checkpoint
      for (final checkpoint in flow.checkpoints) {
        final noteContent = _generateCheckpointNote(checkpoint, flow.title);
        final note = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Checkpoint: ${checkpoint.title}',
          content: noteContent,
          labels: [flow.title, 'checkpoint', checkpoint.type.name],
          color: NoteColors.blue,
          isPinned: false,
          isArchived: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          type: NoteType.text,
        );

        await FlowService.createNote(note);
        notesCount++;
      }

      // Generate alarms for milestones and deadlines
      for (final checkpoint in flow.checkpoints) {
        if (checkpoint.type == CheckpointType.milestone ||
            checkpoint.type == CheckpointType.review) {
          final scheduledTime = DateTime.now().add(
            Duration(days: checkpoint.order + 1),
          );

          final alarm = FlowAlarm(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Deadline: ${checkpoint.title}',
            description: 'Reminder for ${flow.title} milestone',
            scheduledTime: scheduledTime,
            isActive: true,
            type: AlarmType.deadline,
            repeat: AlarmRepeat.none,
            flowId: flow.id,
            checkpointId: checkpoint.id,
            createdAt: DateTime.now(),
          );

          await FlowService.createAlarm(alarm);
          alarmsCount++;
        }
      }

      // Generate meeting placeholders for collaboration checkpoints
      for (final checkpoint in flow.checkpoints) {
        if (checkpoint.requirements.any(
          (req) =>
              req.toLowerCase().contains('meeting') ||
              req.toLowerCase().contains('review') ||
              req.toLowerCase().contains('discussion'),
        )) {
          final meetingNote = Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Meeting: ${checkpoint.title} Review',
            content: _generateMeetingContent(checkpoint, flow.title),
            labels: [flow.title, 'meeting', 'review'],
            color: NoteColors.green,
            isPinned: false,
            isArchived: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            type: NoteType.text,
          );

          await FlowService.createNote(meetingNote);
          meetingsCount++;
        }
      }
    } catch (e) {
      // Continue even if some components fail
      print('Error generating flow components: $e');
    }

    return {
      'notes_count': notesCount,
      'alarms_count': alarmsCount,
      'meetings_count': meetingsCount,
    };
  }

  String _generateCheckpointNote(FlowCheckpoint checkpoint, String flowTitle) {
    final requirements = checkpoint.requirements
        .map((req) => '• $req')
        .join('\n');
    final deliverables = checkpoint.deliverables
        .map((del) => '• $del')
        .join('\n');
    final status = checkpoint.isCompleted ? '✅ Completed' : '⏳ Pending';

    return '''# ${checkpoint.title}

## Overview
${checkpoint.description}

## Requirements
$requirements

## Deliverables
$deliverables

## Estimated Time
${checkpoint.estimatedTime}

## Status
$status

## Notes
- Priority: ${checkpoint.type.name.toUpperCase()}
- Order: ${checkpoint.order + 1}
- Part of: $flowTitle

---
*Auto-generated by Buddy AI*''';
  }

  String _generateMeetingContent(FlowCheckpoint checkpoint, String flowTitle) {
    final deliverables = checkpoint.deliverables.join(', ');

    return '''# Meeting: ${checkpoint.title} Review

## Purpose
Review progress and align on ${checkpoint.title} for $flowTitle project.

## Agenda
1. Progress update on ${checkpoint.title}
2. Review deliverables: $deliverables
3. Discuss challenges and blockers
4. Next steps and action items

## Participants
- [ ] Project lead
- [ ] Team members
- [ ] Stakeholders (if needed)

## Meeting Details
- **Duration**: 30-60 minutes
- **Type**: ${checkpoint.type.name} review
- **Preparation**: Review checkpoint requirements

## Action Items
- [ ] Review checkpoint completion
- [ ] Assign next tasks
- [ ] Schedule follow-up if needed

---
*Auto-scheduled by Buddy AI*''';
  }
}
