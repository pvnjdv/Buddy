# Database Migration for Collaboration Features
"""Add collaboration models

Revision ID: add_collaboration_models
Revises: previous_migration
Create Date: 2025-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = 'add_collaboration_models'
down_revision = 'previous_migration'  # Replace with your latest migration
branch_labels = None
depends_on = None

def upgrade():
    # Create collaboration status and role enums
    collaboration_status_enum = sa.Enum(
        'pending', 'accepted', 'rejected', 'active', 'completed', 'cancelled',
        name='collaborationstatus'
    )
    collaboration_role_enum = sa.Enum(
        'owner', 'admin', 'contributor', 'viewer',
        name='collaborationrole'
    )
    
    collaboration_status_enum.create(op.get_bind())
    collaboration_role_enum.create(op.get_bind())
    
    # Create project_collaborations table
    op.create_table(
        'project_collaborations',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('project_id', sa.Integer(), sa.ForeignKey('project_flows.id'), nullable=False),
        sa.Column('owner_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('description', sa.Text()),
        sa.Column('status', collaboration_status_enum, default='active'),
        sa.Column('settings', sa.JSON(), default={}),
        sa.Column('created_at', sa.DateTime(), default=sa.func.utcnow()),
        sa.Column('updated_at', sa.DateTime(), default=sa.func.utcnow(), onupdate=sa.func.utcnow()),
    )
    
    # Create collaboration_members table
    op.create_table(
        'collaboration_members',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('collaboration_id', sa.String(36), sa.ForeignKey('project_collaborations.id'), nullable=False),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('role', collaboration_role_enum, default='contributor'),
        sa.Column('permissions', sa.JSON(), default={}),
        sa.Column('joined_at', sa.DateTime(), default=sa.func.utcnow()),
        sa.Column('last_active', sa.DateTime(), default=sa.func.utcnow()),
    )
    
    # Create collaboration_invitations table
    op.create_table(
        'collaboration_invitations',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('collaboration_id', sa.String(36), sa.ForeignKey('project_collaborations.id'), nullable=False),
        sa.Column('inviter_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('invitee_mobile', sa.String(20), nullable=False),
        sa.Column('invitee_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=True),
        sa.Column('role', collaboration_role_enum, default='contributor'),
        sa.Column('status', collaboration_status_enum, default='pending'),
        sa.Column('message', sa.Text()),
        sa.Column('invited_at', sa.DateTime(), default=sa.func.utcnow()),
        sa.Column('responded_at', sa.DateTime()),
        sa.Column('expires_at', sa.DateTime()),
    )
    
    # Create ai_collaboration_insights table
    op.create_table(
        'ai_collaboration_insights',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('collaboration_id', sa.String(36), sa.ForeignKey('project_collaborations.id'), nullable=False),
        sa.Column('insight_type', sa.String(50), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('metadata', sa.JSON(), default={}),
        sa.Column('relevance_score', sa.Integer(), default=0),
        sa.Column('is_read', sa.Boolean(), default=False),
        sa.Column('created_at', sa.DateTime(), default=sa.func.utcnow()),
    )
    
    # Create collaboration_activities table
    op.create_table(
        'collaboration_activities',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('collaboration_id', sa.String(36), sa.ForeignKey('project_collaborations.id'), nullable=False),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('activity_type', sa.String(50), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('metadata', sa.JSON(), default={}),
        sa.Column('created_at', sa.DateTime(), default=sa.func.utcnow()),
    )
    
    # Create indexes for better performance
    op.create_index('idx_collaboration_project_id', 'project_collaborations', ['project_id'])
    op.create_index('idx_collaboration_owner_id', 'project_collaborations', ['owner_id'])
    op.create_index('idx_collaboration_status', 'project_collaborations', ['status'])
    
    op.create_index('idx_member_collaboration_id', 'collaboration_members', ['collaboration_id'])
    op.create_index('idx_member_user_id', 'collaboration_members', ['user_id'])
    
    op.create_index('idx_invitation_collaboration_id', 'collaboration_invitations', ['collaboration_id'])
    op.create_index('idx_invitation_invitee_mobile', 'collaboration_invitations', ['invitee_mobile'])
    op.create_index('idx_invitation_status', 'collaboration_invitations', ['status'])
    
    op.create_index('idx_insight_collaboration_id', 'ai_collaboration_insights', ['collaboration_id'])
    op.create_index('idx_insight_type', 'ai_collaboration_insights', ['insight_type'])
    op.create_index('idx_insight_relevance', 'ai_collaboration_insights', ['relevance_score'])
    
    op.create_index('idx_activity_collaboration_id', 'collaboration_activities', ['collaboration_id'])
    op.create_index('idx_activity_user_id', 'collaboration_activities', ['user_id'])
    op.create_index('idx_activity_type', 'collaboration_activities', ['activity_type'])

def downgrade():
    # Drop indexes
    op.drop_index('idx_activity_type')
    op.drop_index('idx_activity_user_id')
    op.drop_index('idx_activity_collaboration_id')
    
    op.drop_index('idx_insight_relevance')
    op.drop_index('idx_insight_type')
    op.drop_index('idx_insight_collaboration_id')
    
    op.drop_index('idx_invitation_status')
    op.drop_index('idx_invitation_invitee_mobile')
    op.drop_index('idx_invitation_collaboration_id')
    
    op.drop_index('idx_member_user_id')
    op.drop_index('idx_member_collaboration_id')
    
    op.drop_index('idx_collaboration_status')
    op.drop_index('idx_collaboration_owner_id')
    op.drop_index('idx_collaboration_project_id')
    
    # Drop tables
    op.drop_table('collaboration_activities')
    op.drop_table('ai_collaboration_insights')
    op.drop_table('collaboration_invitations')
    op.drop_table('collaboration_members')
    op.drop_table('project_collaborations')
    
    # Drop enums
    op.execute('DROP TYPE collaborationrole')
    op.execute('DROP TYPE collaborationstatus')
