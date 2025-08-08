import asyncio
import json
import re
from typing import List, Dict, Any, Optional
from datetime import datetime
from app.ai.model_loader import UnifiedAIClient

class BuddyAI:
    """Enhanced Buddy AI for project flow generation and assistance"""
    
    def __init__(self):
        # Initialize the unified AI client
        self.ai_client = UnifiedAIClient()
        
        self.flow_templates = {
            "website": {
                "title": "Website Development Project",
                "difficulty": "medium",
                "estimated_duration": "2-3 weeks",
                "tags": ["web", "frontend", "development"],
                "checkpoints": [
                    {
                        "title": "Planning & Research",
                        "description": "Define requirements, research target audience, and plan the project scope.",
                        "type": "milestone",
                        "estimated_time": "1-2 days",
                        "requirements": ["Project brief", "Target audience research"],
                        "deliverables": ["Requirements document", "Project timeline", "Research findings"]
                    },
                    {
                        "title": "Design & Wireframing",
                        "description": "Create wireframes, mockups, and design system for the website.",
                        "type": "task",
                        "estimated_time": "2-3 days",
                        "requirements": ["Approved requirements", "Design tools", "Brand guidelines"],
                        "deliverables": ["Wireframes", "Visual designs", "Style guide", "Responsive layouts"]
                    },
                    {
                        "title": "Frontend Development",
                        "description": "Build the user interface using HTML, CSS, and JavaScript.",
                        "type": "task",
                        "estimated_time": "5-7 days",
                        "requirements": ["Approved designs", "Development environment", "Code editor"],
                        "deliverables": ["HTML structure", "CSS styling", "JavaScript functionality", "Responsive design"]
                    },
                    {
                        "title": "Content Integration",
                        "description": "Add and optimize content, images, and media for the website.",
                        "type": "task",
                        "estimated_time": "2-3 days",
                        "requirements": ["Website structure", "Content materials", "Image assets"],
                        "deliverables": ["Integrated content", "Optimized images", "SEO-ready pages"]
                    },
                    {
                        "title": "Testing & Launch",
                        "description": "Test functionality, fix bugs, and deploy the website.",
                        "type": "review",
                        "estimated_time": "2-3 days",
                        "requirements": ["Completed website", "Testing checklist", "Hosting setup"],
                        "deliverables": ["Test results", "Bug fixes", "Live website", "Documentation"]
                    }
                ]
            },
            "mobile_app": {
                "title": "Mobile App Development",
                "difficulty": "hard",
                "estimated_duration": "4-6 weeks",
                "tags": ["mobile", "app", "development"],
                "checkpoints": [
                    {
                        "title": "Concept & Market Research",
                        "description": "Define app concept, research market, and analyze competitors.",
                        "type": "milestone",
                        "estimated_time": "2-3 days",
                        "requirements": ["App idea", "Market research tools"],
                        "deliverables": ["App concept document", "Market analysis", "Competitor research"]
                    },
                    {
                        "title": "Technical Planning",
                        "description": "Choose technology stack and design app architecture.",
                        "type": "task",
                        "estimated_time": "2-3 days",
                        "requirements": ["Concept approval", "Technical knowledge"],
                        "deliverables": ["Tech stack decision", "Architecture diagram", "Development plan"]
                    },
                    {
                        "title": "UI/UX Design",
                        "description": "Design user interface and user experience flow.",
                        "type": "task",
                        "estimated_time": "4-5 days",
                        "requirements": ["App concept", "Design tools", "User research"],
                        "deliverables": ["UI mockups", "User flow diagrams", "Design system", "Prototype"]
                    },
                    {
                        "title": "Development Setup",
                        "description": "Set up development environment and project structure.",
                        "type": "task",
                        "estimated_time": "1-2 days",
                        "requirements": ["Approved designs", "Development tools"],
                        "deliverables": ["Project setup", "Development environment", "Basic app structure"]
                    },
                    {
                        "title": "Core Feature Development",
                        "description": "Implement main app features and functionality.",
                        "type": "task",
                        "estimated_time": "2-3 weeks",
                        "requirements": ["Setup completion", "Feature specifications"],
                        "deliverables": ["Core features", "App navigation", "Data management", "API integration"]
                    },
                    {
                        "title": "Testing & Optimization",
                        "description": "Test app thoroughly and optimize performance.",
                        "type": "testing",
                        "estimated_time": "3-5 days",
                        "requirements": ["Feature completion", "Test devices"],
                        "deliverables": ["Test results", "Performance optimizations", "Bug fixes"]
                    },
                    {
                        "title": "Deployment & Launch",
                        "description": "Deploy to app stores and manage launch process.",
                        "type": "review",
                        "estimated_time": "2-3 days",
                        "requirements": ["Tested app", "Store accounts", "Marketing materials"],
                        "deliverables": ["App store listing", "Published app", "Launch strategy"]
                    }
                ]
            },
            "business": {
                "title": "Business Project",
                "difficulty": "medium",
                "estimated_duration": "2-4 weeks",
                "tags": ["business", "strategy", "planning"],
                "checkpoints": [
                    {
                        "title": "Business Analysis",
                        "description": "Analyze current business situation and identify opportunities.",
                        "type": "milestone",
                        "estimated_time": "2-3 days",
                        "requirements": ["Business data", "Market information"],
                        "deliverables": ["Business analysis report", "SWOT analysis", "Opportunity assessment"]
                    },
                    {
                        "title": "Strategy Development",
                        "description": "Develop business strategy and action plan.",
                        "type": "task",
                        "estimated_time": "3-4 days",
                        "requirements": ["Analysis completion", "Stakeholder input"],
                        "deliverables": ["Business strategy", "Action plan", "Success metrics"]
                    },
                    {
                        "title": "Implementation Planning",
                        "description": "Create detailed implementation plan with timelines and resources.",
                        "type": "task",
                        "estimated_time": "2-3 days",
                        "requirements": ["Approved strategy", "Resource assessment"],
                        "deliverables": ["Implementation plan", "Resource allocation", "Timeline"]
                    },
                    {
                        "title": "Execution & Monitoring",
                        "description": "Execute the plan and monitor progress.",
                        "type": "task",
                        "estimated_time": "1-2 weeks",
                        "requirements": ["Implementation plan", "Team coordination"],
                        "deliverables": ["Progress reports", "Milestone achievements", "Adjustments"]
                    },
                    {
                        "title": "Review & Optimization",
                        "description": "Review results and optimize for future improvements.",
                        "type": "review",
                        "estimated_time": "2-3 days",
                        "requirements": ["Execution completion", "Performance data"],
                        "deliverables": ["Results analysis", "Lessons learned", "Future recommendations"]
                    }
                ]
            }
        }
    
    async def generate_project_flow(self, description: str, user_preferences: Optional[Dict] = None) -> Dict[str, Any]:
        """Generate a project flow based on description"""
        # Simulate API delay
        await asyncio.sleep(1)
        
        # Analyze description to determine project type
        project_type = self._analyze_project_type(description)
        
        # Get base template
        if project_type in self.flow_templates:
            flow_data = self.flow_templates[project_type].copy()
        else:
            flow_data = self._generate_generic_flow(description)
        
        # Customize based on description
        flow_data = self._customize_flow(flow_data, description, user_preferences or {})
        
        return flow_data
    
    def _analyze_project_type(self, description: str) -> str:
        """Analyze description to determine project type"""
        description_lower = description.lower()
        
        web_keywords = ["website", "web", "landing page", "blog", "portfolio", "ecommerce"]
        app_keywords = ["app", "mobile", "android", "ios", "application"]
        business_keywords = ["business", "startup", "strategy", "plan", "marketing", "sales"]
        
        if any(keyword in description_lower for keyword in web_keywords):
            return "website"
        elif any(keyword in description_lower for keyword in app_keywords):
            return "mobile_app"
        elif any(keyword in description_lower for keyword in business_keywords):
            return "business"
        else:
            return "generic"
    
    def _generate_generic_flow(self, description: str) -> Dict[str, Any]:
        """Generate a generic flow for unrecognized project types"""
        return {
            "title": self._extract_title(description),
            "difficulty": "medium",
            "estimated_duration": "2-3 weeks",
            "tags": ["project", "custom"],
            "checkpoints": [
                {
                    "title": "Project Planning",
                    "description": "Define project scope, goals, and requirements.",
                    "type": "milestone",
                    "estimated_time": "1-2 days",
                    "requirements": ["Project brief", "Stakeholder input"],
                    "deliverables": ["Project plan", "Requirements document", "Timeline"]
                },
                {
                    "title": "Research & Analysis",
                    "description": "Conduct necessary research and analysis for the project.",
                    "type": "task",
                    "estimated_time": "2-3 days",
                    "requirements": ["Project plan", "Research tools"],
                    "deliverables": ["Research findings", "Analysis report", "Recommendations"]
                },
                {
                    "title": "Design & Development",
                    "description": "Create and develop the main project deliverables.",
                    "type": "task",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Research completion", "Development tools"],
                    "deliverables": ["Project deliverables", "Progress reports", "Quality checks"]
                },
                {
                    "title": "Testing & Refinement",
                    "description": "Test, review, and refine the project outputs.",
                    "type": "testing",
                    "estimated_time": "2-3 days",
                    "requirements": ["Development completion", "Testing criteria"],
                    "deliverables": ["Test results", "Refinements", "Quality assurance"]
                },
                {
                    "title": "Finalization & Delivery",
                    "description": "Finalize the project and prepare for delivery.",
                    "type": "review",
                    "estimated_time": "1-2 days",
                    "requirements": ["Testing completion", "Delivery criteria"],
                    "deliverables": ["Final deliverables", "Documentation", "Project closure"]
                }
            ]
        }
    
    def _extract_title(self, description: str) -> str:
        """Extract a title from the description"""
        # Clean and limit description for title
        title = description.strip()
        if len(title) > 50:
            title = title[:47] + "..."
        return title
    
    def _customize_flow(self, flow_data: Dict[str, Any], description: str, preferences: Dict) -> Dict[str, Any]:
        """Customize flow based on specific description and preferences"""
        # Customize title if it's generic
        if flow_data["title"] in ["Website Development Project", "Mobile App Development", "Business Project"]:
            custom_title = self._extract_title(description)
            if len(custom_title) > 10:  # Only replace if we have a meaningful custom title
                flow_data["title"] = custom_title
        
        # Adjust difficulty based on keywords
        description_lower = description.lower()
        if any(word in description_lower for word in ["simple", "basic", "easy", "beginner"]):
            flow_data["difficulty"] = "easy"
        elif any(word in description_lower for word in ["complex", "advanced", "professional", "enterprise"]):
            flow_data["difficulty"] = "hard"
        
        # Adjust timeline based on scope indicators
        if any(word in description_lower for word in ["quick", "fast", "rapid", "asap"]):
            flow_data["estimated_duration"] = "1 week"
        elif any(word in description_lower for word in ["comprehensive", "detailed", "thorough", "complete"]):
            if flow_data["difficulty"] == "hard":
                flow_data["estimated_duration"] = "6-8 weeks"
            else:
                flow_data["estimated_duration"] = "4-5 weeks"
        
        # Add custom tags based on description
        additional_tags = []
        if "responsive" in description_lower:
            additional_tags.append("responsive")
        if "ecommerce" in description_lower or "shop" in description_lower:
            additional_tags.append("ecommerce")
        if "portfolio" in description_lower:
            additional_tags.append("portfolio")
        if "blog" in description_lower:
            additional_tags.append("blog")
        
        flow_data["tags"].extend(additional_tags)
        
        return flow_data
    
    async def get_checkpoint_help(self, flow, checkpoint, chat_history: List[str]) -> str:
        """Generate help content for a specific checkpoint"""
        # Simulate API delay
        await asyncio.sleep(0.5)
        
        help_templates = {
            "Planning & Research": """
🎯 **Planning & Research Help**

**Getting Started:**
1. **Define Your Goals**: Write down what you want to achieve
2. **Research Your Audience**: Who will use/benefit from this?
3. **Gather Requirements**: List all features and functionality needed
4. **Set Success Metrics**: How will you measure success?

**Tips:**
• Start with a simple one-page outline
• Use tools like Google Trends for research
• Create user personas if applicable
• Set realistic timelines

**Resources:**
• Project planning templates
• Market research tools
• Competitor analysis guides

Need more specific help with any part? Just ask!
            """,
            "Design": """
🎨 **Design & Wireframing Help**

**Design Process:**
1. **Start with Sketches**: Draw rough layouts on paper first
2. **Create Wireframes**: Use tools like Figma, Sketch, or even pen & paper
3. **Design System**: Choose colors, fonts, and styling
4. **Mobile-First**: Design for mobile devices first

**Recommended Tools:**
• **Free**: Figma, Canva, GIMP
• **Paid**: Adobe Creative Suite, Sketch
• **Templates**: Bootstrap, Material Design

**Best Practices:**
• Keep it simple and user-friendly
• Ensure good contrast for readability
• Test designs with potential users
• Make it accessible

Want help with specific design decisions? I'm here to assist!
            """,
            "Development": """
💻 **Development Help**

**Getting Started:**
1. **Set Up Environment**: Install necessary tools and software
2. **Project Structure**: Organize your files and folders
3. **Version Control**: Use Git for tracking changes
4. **Start Small**: Build one feature at a time

**Common Tools:**
• **Code Editors**: VS Code, Sublime Text, Atom
• **Version Control**: Git + GitHub/GitLab
• **Frameworks**: React, Vue, Angular (for web)
• **Package Managers**: npm, yarn

**Development Tips:**
• Write clean, commented code
• Test frequently as you build
• Use consistent naming conventions
• Save and backup regularly

**Learning Resources:**
• MDN Web Docs for web development
• Stack Overflow for problem-solving
• GitHub for code examples

Stuck on a specific technical issue? Let me know what you're working on!
            """,
            "Testing": """
🧪 **Testing & Quality Assurance Help**

**Testing Checklist:**
1. **Functionality Testing**: Does everything work as expected?
2. **Cross-Platform Testing**: Test on different devices/browsers
3. **Performance Testing**: Check loading speeds and responsiveness
4. **User Testing**: Get feedback from real users

**Types of Testing:**
• **Manual Testing**: Click through everything yourself
• **Automated Testing**: Use tools to run tests automatically
• **User Acceptance Testing**: Let others try it out
• **Accessibility Testing**: Ensure it works for everyone

**Testing Tools:**
• Browser dev tools for web projects
• Lighthouse for performance auditing
• User testing platforms like UserTesting.com
• Accessibility checkers

**Common Issues to Check:**
• Broken links or buttons
• Mobile responsiveness
• Loading times
• Error handling

Need help setting up specific tests? I can guide you through it!
            """
        }
        
        # Find the most relevant help template
        checkpoint_title = checkpoint.title.lower()
        help_content = None
        
        for template_key, template_content in help_templates.items():
            if any(word in checkpoint_title for word in template_key.lower().split()):
                help_content = template_content
                break
        
        # If no specific template found, generate generic help
        if not help_content:
            help_content = f"""
🚀 **Help for: {checkpoint.title}**

**What to do:**
{checkpoint.description}

**Requirements:**
{chr(10).join(f'• {req}' for req in checkpoint.requirements) if checkpoint.requirements else '• Review the checkpoint description above'}

**Expected Deliverables:**
{chr(10).join(f'• {deliverable}' for deliverable in checkpoint.deliverables) if checkpoint.deliverables else '• Complete the tasks as described'}

**General Tips:**
• Break this checkpoint into smaller tasks
• Set aside dedicated time blocks for focused work
• Don't hesitate to research and learn as you go
• Ask for feedback if you're unsure about anything
• Celebrate small wins along the way!

**Estimated Time:** {checkpoint.estimated_time}

Need more specific guidance? Just ask me about any particular aspect you're struggling with!
            """
        
        return help_content.strip()
    
    async def generate_progress_message(self, flow, checkpoint_index: int, is_completed: bool) -> str:
        """Generate encouraging progress messages"""
        await asyncio.sleep(0.3)
        
        total_checkpoints = len(flow.checkpoints)
        progress_percentage = ((checkpoint_index + 1) / total_checkpoints) * 100 if is_completed else (checkpoint_index / total_checkpoints) * 100
        
        if is_completed:
            messages = [
                f"🎉 Awesome! You've completed another checkpoint. You're now {progress_percentage:.0f}% done with {flow.title}!",
                f"✅ Great progress! Checkpoint completed. Keep up the momentum - you're {progress_percentage:.0f}% through your project!",
                f"🚀 Well done! Another milestone reached. You're making excellent progress on {flow.title}!",
                f"🌟 Fantastic work! You've just finished another important step. {progress_percentage:.0f}% complete!",
                f"💪 You're crushing it! Another checkpoint down. Your project is really taking shape!"
            ]
            
            if progress_percentage >= 100:
                return f"🏆 CONGRATULATIONS! You've completed your entire project flow for '{flow.title}'! Amazing work - you should be proud of what you've accomplished!"
            elif progress_percentage >= 75:
                return f"🔥 You're in the final stretch! Just a few more checkpoints to go. You've got this!"
            elif progress_percentage >= 50:
                return f"⭐ You're over halfway done with {flow.title}! The finish line is getting closer!"
        else:
            messages = [
                f"That's okay! Sometimes we need to revisit steps. You're still making progress on {flow.title}.",
                f"No worries - taking a step back can help ensure quality. Keep moving forward!",
                f"Progress isn't always linear. You're still on track with your project!",
                f"Taking time to review and adjust is part of the process. Stay focused!"
            ]
        
        import random
        return random.choice(messages) if messages else "Keep up the great work!"
    
    async def analyze_flow_request(self, message: str) -> Dict[str, Any]:
        """Analyze a message to see if it's a flow creation request"""
        message_lower = message.lower()
        
        # Check for flow trigger words
        flow_triggers = [
            "create flow", "generate flow", "flow:", "make a flow",
            "project flow", "workflow", "timeline", "roadmap"
        ]
        
        is_flow_request = any(trigger in message_lower for trigger in flow_triggers)
        
        if is_flow_request:
            # Extract project description
            description = message
            for trigger in flow_triggers:
                if trigger in message_lower:
                    index = message_lower.find(trigger)
                    description = message[index + len(trigger):].strip()
                    break
            
            # Remove common prefixes
            for prefix in ["for", "to", "about", ":"]:
                if description.startswith(prefix):
                    description = description[len(prefix):].strip()
            
            return {
                "is_flow_request": True,
                "project_description": description,
                "confidence": 0.9
            }
        
        return {
            "is_flow_request": False,
            "project_description": "",
            "confidence": 0.0
        }

    async def generate_ai_response(self, prompt: str, chat_history: List[Dict[str, str]] = None) -> str:
        """Generate AI response using the unified AI client"""
        try:
            return await self.ai_client.generate_response(prompt, chat_history or [])
        except Exception as e:
            print(f"Error generating AI response: {e}")
            return "I apologize, but I'm having trouble generating a response right now. Please try again later."
