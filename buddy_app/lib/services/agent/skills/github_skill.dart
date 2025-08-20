import '../buddy_orchestrator.dart';
import 'dart:io';

class GitHubSkill {
  bool matches(String p) {
    final l = p.toLowerCase();
    return l.contains('github') ||
        l.contains('git ') ||
        l.contains('repository') ||
        l.contains('commit') ||
        l.contains('push') ||
        l.contains('pull') ||
        l.contains('clone') ||
        l.contains('branch');
  }

  Future<AgentResult> execute(String p) async {
    final l = p.toLowerCase();

    try {
      if (l.contains('clone')) {
        return await _handleClone(p);
      } else if (l.contains('commit')) {
        return await _handleCommit(p);
      } else if (l.contains('push')) {
        return await _handlePush(p);
      } else if (l.contains('pull')) {
        return await _handlePull(p);
      } else if (l.contains('status')) {
        return await _handleStatus(p);
      } else if (l.contains('create repository') || l.contains('new repo')) {
        return await _handleCreateRepo(p);
      } else {
        return AgentResult(
          handled: true,
          message:
              'I can help you with GitHub operations like clone, commit, push, pull, status, and creating repositories. What would you like to do?',
          extra: {'action': 'github_help'},
        );
      }
    } catch (e) {
      return AgentResult(
        handled: true,
        message: 'GitHub operation failed: $e',
        extra: {'error': e.toString()},
      );
    }
  }

  Future<AgentResult> _handleClone(String prompt) async {
    // Extract repository URL from prompt
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(prompt);

    if (match != null) {
      final url = match.group(0)!;
      final result = await Process.run('git', ['clone', url]);

      if (result.exitCode == 0) {
        return AgentResult(
          handled: true,
          message: 'Repository cloned successfully!',
          extra: {'action': 'clone', 'url': url, 'output': result.stdout},
        );
      } else {
        return AgentResult(
          handled: true,
          message: 'Clone failed: ${result.stderr}',
          extra: {'action': 'clone', 'error': result.stderr},
        );
      }
    }

    return AgentResult(
      handled: true,
      message: 'Please provide a valid GitHub repository URL to clone.',
      extra: {'action': 'clone_help'},
    );
  }

  Future<AgentResult> _handleCommit(String prompt) async {
    // Extract commit message
    String message = 'Auto commit by Buddy';
    final msgMatch = RegExp(r'"([^"]+)"').firstMatch(prompt);
    if (msgMatch != null) {
      message = msgMatch.group(1)!;
    }

    // Add all files and commit
    await Process.run('git', ['add', '.']);
    final result = await Process.run('git', ['commit', '-m', message]);

    if (result.exitCode == 0) {
      return AgentResult(
        handled: true,
        message: 'Changes committed successfully: "$message"',
        extra: {
          'action': 'commit',
          'message': message,
          'output': result.stdout,
        },
      );
    } else {
      return AgentResult(
        handled: true,
        message: 'Commit failed: ${result.stderr}',
        extra: {'action': 'commit', 'error': result.stderr},
      );
    }
  }

  Future<AgentResult> _handlePush(String prompt) async {
    final result = await Process.run('git', ['push']);

    if (result.exitCode == 0) {
      return AgentResult(
        handled: true,
        message: 'Changes pushed to remote repository successfully!',
        extra: {'action': 'push', 'output': result.stdout},
      );
    } else {
      return AgentResult(
        handled: true,
        message: 'Push failed: ${result.stderr}',
        extra: {'action': 'push', 'error': result.stderr},
      );
    }
  }

  Future<AgentResult> _handlePull(String prompt) async {
    final result = await Process.run('git', ['pull']);

    if (result.exitCode == 0) {
      return AgentResult(
        handled: true,
        message: 'Repository updated successfully!',
        extra: {'action': 'pull', 'output': result.stdout},
      );
    } else {
      return AgentResult(
        handled: true,
        message: 'Pull failed: ${result.stderr}',
        extra: {'action': 'pull', 'error': result.stderr},
      );
    }
  }

  Future<AgentResult> _handleStatus(String prompt) async {
    final result = await Process.run('git', ['status', '--porcelain']);

    if (result.exitCode == 0) {
      final output = result.stdout.toString();
      final hasChanges = output.trim().isNotEmpty;

      return AgentResult(
        handled: true,
        message: hasChanges
            ? 'Repository has uncommitted changes:\n$output'
            : 'Repository is clean - no uncommitted changes.',
        extra: {
          'action': 'status',
          'output': output,
          'has_changes': hasChanges,
        },
      );
    } else {
      return AgentResult(
        handled: true,
        message: 'Status check failed: ${result.stderr}',
        extra: {'action': 'status', 'error': result.stderr},
      );
    }
  }

  Future<AgentResult> _handleCreateRepo(String prompt) async {
    // This would integrate with GitHub API to create repositories
    return AgentResult(
      handled: true,
      message:
          'GitHub repository creation is not yet implemented. You can create repositories manually on GitHub.com or use the GitHub CLI.',
      extra: {'action': 'create_repo', 'status': 'not_implemented'},
    );
  }
}
