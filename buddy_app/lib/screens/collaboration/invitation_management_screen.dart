import 'package:flutter/material.dart';
import '../../models/collaboration_models.dart';
import '../../config/settings/theme_config.dart';

class InvitationManagementScreen extends StatelessWidget {
  final List<CollaborationInvitation> invitations;
  final Function(CollaborationInvitation, bool) onInvitationResponse;

  const InvitationManagementScreen({
    super.key,
    required this.invitations,
    required this.onInvitationResponse,
  });

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No invitations',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see collaboration invitations here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invitations.length,
      itemBuilder: (context, index) {
        final invitation = invitations[index];
        return _buildInvitationCard(context, invitation);
      },
    );
  }

  Widget _buildInvitationCard(
    BuildContext context,
    CollaborationInvitation invitation,
  ) {
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
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    invitation.inviterName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.collaborationName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Invited by ${invitation.inviterName}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(invitation.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    invitation.role.name.toUpperCase(),
                    style: TextStyle(
                      color: _getRoleColor(invitation.role),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            if (invitation.message != null &&
                invitation.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  invitation.message!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onInvitationResponse(invitation, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onInvitationResponse(invitation, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Invited ${_formatDateTime(invitation.invitedAt)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (invitation.expiresAt != null)
              Text(
                'Expires ${_formatDateTime(invitation.expiresAt!)}',
                style: TextStyle(color: Colors.orange[600], fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(CollaborationRole role) {
    switch (role) {
      case CollaborationRole.owner:
        return Colors.purple;
      case CollaborationRole.admin:
        return Colors.blue;
      case CollaborationRole.contributor:
        return Colors.green;
      case CollaborationRole.viewer:
        return Colors.orange;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
