# Enhanced AI Collaboration Methods for BuddyAI
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import json

class AICollaborationMethods:
    """
    Enhanced AI methods for collaboration management and insights generation
    """
    
    async def generate_collaboration_insights(self, project_flow) -> List[Dict[str, Any]]:
        """
        Generate AI-powered insights for project collaboration
        """
        insights = []
        
        # Analyze project progress
        progress_insight = await self._analyze_project_progress(project_flow)
        if progress_insight:
            insights.append(progress_insight)
        
        # Suggest next steps
        next_steps_insight = await self._suggest_next_steps(project_flow)
        if next_steps_insight:
            insights.append(next_steps_insight)
        
        # Identify potential blockers
        blockers_insight = await self._identify_blockers(project_flow)
        if blockers_insight:
            insights.append(blockers_insight)
        
        # Suggest team collaboration opportunities
        collaboration_insight = await self._suggest_collaboration_opportunities(project_flow)
        if collaboration_insight:
            insights.append(collaboration_insight)
        
        return insights
    
    async def _analyze_project_progress(self, project_flow) -> Optional[Dict[str, Any]]:
        """Analyze overall project progress and generate insights"""
        
        total_checkpoints = len(project_flow.checkpoints)
        completed_checkpoints = sum(1 for cp in project_flow.checkpoints if cp.is_completed)
        
        if total_checkpoints == 0:
            return None
        
        progress_percentage = (completed_checkpoints / total_checkpoints) * 100
        
        # Generate progress analysis prompt
        prompt = f"""
        Analyze this project progress and provide insights:
        
        Project: {project_flow.title}
        Description: {project_flow.description}
        Total Checkpoints: {total_checkpoints}
        Completed: {completed_checkpoints}
        Progress: {progress_percentage:.1f}%
        
        Current checkpoint details:
        {self._format_checkpoints_for_analysis(project_flow.checkpoints)}
        
        Provide a brief analysis of the project's current state and suggest improvements.
        Focus on: pace, quality, potential risks, and team collaboration needs.
        """
        
        try:
            analysis = await self.ai_client.generate_response(prompt)
            
            return {
                "type": "progress",
                "title": f"Project Progress Analysis ({progress_percentage:.1f}%)",
                "content": analysis,
                "relevance_score": 90,
                "metadata": {
                    "progress_percentage": progress_percentage,
                    "completed_checkpoints": completed_checkpoints,
                    "total_checkpoints": total_checkpoints
                }
            }
        except Exception as e:
            print(f"Error generating progress insight: {e}")
            return None
    
    async def _suggest_next_steps(self, project_flow) -> Optional[Dict[str, Any]]:
        """Suggest next actionable steps for the project"""
        
        # Find current checkpoint
        current_checkpoint = None
        for cp in project_flow.checkpoints:
            if not cp.is_completed:
                current_checkpoint = cp
                break
        
        if not current_checkpoint:
            return None
        
        prompt = f"""
        Based on this project's current state, suggest the next 3-5 actionable steps:
        
        Project: {project_flow.title}
        Current Checkpoint: {current_checkpoint.title}
        Description: {current_checkpoint.description}
        Requirements: {', '.join(current_checkpoint.requirements)}
        Deliverables: {', '.join(current_checkpoint.deliverables)}
        Estimated Time: {current_checkpoint.estimated_time}
        
        Provide specific, actionable next steps that the team should focus on.
        Consider dependencies, priorities, and collaboration opportunities.
        """
        
        try:
            suggestions = await self.ai_client.generate_response(prompt)
            
            return {
                "type": "suggestion",
                "title": "Next Steps Recommendations",
                "content": suggestions,
                "relevance_score": 85,
                "metadata": {
                    "current_checkpoint_id": current_checkpoint.id,
                    "checkpoint_title": current_checkpoint.title
                }
            }
        except Exception as e:
            print(f"Error generating next steps insight: {e}")
            return None
    
    async def _identify_blockers(self, project_flow) -> Optional[Dict[str, Any]]:
        """Identify potential blockers and risks in the project"""
        
        # Analyze overdue checkpoints and dependencies
        overdue_checkpoints = []
        for cp in project_flow.checkpoints:
            if not cp.is_completed:
                # Simple heuristic: if checkpoint has high complexity, flag as potential blocker
                if len(cp.requirements) > 3 or "complex" in cp.description.lower():
                    overdue_checkpoints.append(cp)
        
        if not overdue_checkpoints:
            return None
        
        prompt = f"""
        Analyze potential blockers and risks in this project:
        
        Project: {project_flow.title}
        
        Potentially challenging checkpoints:
        {self._format_checkpoints_for_analysis(overdue_checkpoints)}
        
        Identify:
        1. Potential technical blockers
        2. Resource constraints
        3. Dependency issues
        4. Risk mitigation strategies
        5. When additional team members might be needed
        
        Provide actionable recommendations to prevent or resolve these blockers.
        """
        
        try:
            blocker_analysis = await self.ai_client.generate_response(prompt)
            
            return {
                "type": "blocker",
                "title": "Potential Blockers & Risk Analysis",
                "content": blocker_analysis,
                "relevance_score": 95,
                "metadata": {
                    "risk_checkpoints": [cp.id for cp in overdue_checkpoints]
                }
            }
        except Exception as e:
            print(f"Error generating blocker insight: {e}")
            return None
    
    async def _suggest_collaboration_opportunities(self, project_flow) -> Optional[Dict[str, Any]]:
        """Suggest opportunities for team collaboration"""
        
        # Find checkpoints that could benefit from collaboration
        collaboration_checkpoints = []
        for cp in project_flow.checkpoints:
            if not cp.is_completed and (
                "review" in cp.title.lower() or 
                "design" in cp.title.lower() or
                "planning" in cp.title.lower() or
                len(cp.deliverables) > 2
            ):
                collaboration_checkpoints.append(cp)
        
        if not collaboration_checkpoints:
            return None
        
        prompt = f"""
        Suggest collaboration opportunities for this project:
        
        Project: {project_flow.title}
        
        Checkpoints suitable for collaboration:
        {self._format_checkpoints_for_analysis(collaboration_checkpoints)}
        
        Suggest:
        1. Which checkpoints would benefit from multiple team members
        2. Ideal team composition for each task
        3. Collaboration tools and methods
        4. Meeting/sync recommendations
        5. How to divide work effectively
        
        Focus on maximizing team efficiency and knowledge sharing.
        """
        
        try:
            collaboration_suggestions = await self.ai_client.generate_response(prompt)
            
            return {
                "type": "collaboration",
                "title": "Team Collaboration Opportunities",
                "content": collaboration_suggestions,
                "relevance_score": 80,
                "metadata": {
                    "collaboration_checkpoints": [cp.id for cp in collaboration_checkpoints]
                }
            }
        except Exception as e:
            print(f"Error generating collaboration insight: {e}")
            return None
    
    def _format_checkpoints_for_analysis(self, checkpoints) -> str:
        """Format checkpoints for AI analysis"""
        
        formatted = []
        for cp in checkpoints:
            status = "✅ Completed" if cp.is_completed else "⏳ Pending"
            formatted.append(f"""
            Checkpoint: {cp.title}
            Status: {status}
            Description: {cp.description}
            Requirements: {', '.join(cp.requirements) if cp.requirements else 'None'}
            Deliverables: {', '.join(cp.deliverables) if cp.deliverables else 'None'}
            Estimated Time: {cp.estimated_time}
            """)
        
        return '\n'.join(formatted)
    
    async def generate_project_documentation(self, project_flow, collaboration_data: Optional[Dict] = None) -> str:
        """
        Auto-generate comprehensive project documentation
        """
        
        prompt = f"""
        Generate comprehensive project documentation for:
        
        PROJECT OVERVIEW:
        Title: {project_flow.title}
        Description: {project_flow.description}
        Status: {project_flow.status.value}
        Difficulty: {project_flow.difficulty.value}
        Estimated Duration: {project_flow.estimated_duration}
        Created: {project_flow.created_at.strftime('%Y-%m-%d')}
        
        CHECKPOINTS:
        {self._format_checkpoints_for_analysis(project_flow.checkpoints)}
        
        Generate a professional project documentation that includes:
        
        1. Executive Summary
        2. Project Objectives
        3. Scope and Deliverables
        4. Timeline and Milestones
        5. Team Roles and Responsibilities
        6. Technical Requirements
        7. Risk Assessment
        8. Progress Tracking
        9. Quality Assurance
        10. Next Steps
        
        Format it as a well-structured markdown document that can be used by stakeholders.
        """
        
        try:
            documentation = await self.ai_client.generate_response(prompt)
            return documentation
        except Exception as e:
            print(f"Error generating documentation: {e}")
            return ""
    
    async def analyze_team_performance(self, project_flow, team_activities: List[Dict]) -> Dict[str, Any]:
        """
        Analyze team performance and provide insights
        """
        
        # Process team activities data
        user_contributions = {}
        activity_timeline = []
        
        for activity in team_activities:
            user_id = activity.get('user_id')
            if user_id:
                if user_id not in user_contributions:
                    user_contributions[user_id] = 0
                user_contributions[user_id] += 1
            
            activity_timeline.append({
                'date': activity.get('created_at'),
                'type': activity.get('activity_type'),
                'description': activity.get('description')
            })
        
        prompt = f"""
        Analyze team performance for this project:
        
        Project: {project_flow.title}
        Team Size: {len(user_contributions)}
        Total Activities: {len(team_activities)}
        
        User Contributions:
        {json.dumps(user_contributions, indent=2)}
        
        Recent Activities:
        {json.dumps(activity_timeline[-10:], indent=2)}
        
        Provide insights on:
        1. Team productivity and engagement
        2. Work distribution balance
        3. Communication patterns
        4. Areas for improvement
        5. Recognition opportunities
        
        Be constructive and actionable in your recommendations.
        """
        
        try:
            analysis = await self.ai_client.generate_response(prompt)
            
            return {
                "overall_analysis": analysis,
                "user_contributions": user_contributions,
                "total_activities": len(team_activities),
                "team_size": len(user_contributions),
                "most_active_period": self._find_most_active_period(activity_timeline)
            }
        except Exception as e:
            print(f"Error analyzing team performance: {e}")
            return {}
    
    def _find_most_active_period(self, activities: List[Dict]) -> Optional[str]:
        """Find the most active period in project timeline"""
        
        if not activities:
            return None
        
        # Simple implementation - count activities by day
        daily_counts = {}
        for activity in activities:
            if activity.get('date'):
                date_str = activity['date'][:10]  # Get YYYY-MM-DD part
                daily_counts[date_str] = daily_counts.get(date_str, 0) + 1
        
        if daily_counts:
            most_active_date = max(daily_counts, key=daily_counts.get)
            return f"{most_active_date} ({daily_counts[most_active_date]} activities)"
        
        return None

# Add these methods to the existing BuddyAI class
def enhance_buddy_ai_with_collaboration():
    """
    Function to add collaboration methods to BuddyAI class
    Usage: Call this after BuddyAI class definition
    """
    
    # Add collaboration methods to BuddyAI class
    for method_name in dir(AICollaborationMethods):
        if not method_name.startswith('_') or method_name.startswith('_analyze') or method_name.startswith('_suggest') or method_name.startswith('_identify'):
            method = getattr(AICollaborationMethods, method_name)
            if callable(method):
                setattr(BuddyAI, method_name, method)
