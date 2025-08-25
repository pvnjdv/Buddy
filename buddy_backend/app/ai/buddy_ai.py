import asyncio
import json
import re
from typing import List, Dict, Any, Optional
from datetime import datetime
from app.ai.model_loader import UnifiedAIClient
from app.services.rag_service import RAGService

class BuddyAI:
    """
    Advanced AI Assistant with GitHub Copilot-like capabilities
    - Dynamic template generation (no hardcoded templates)
    - Full user context awareness
    - Code generation and execution
    - Intelligent project management
    - RAG-enhanced responses
    """
    
    def __init__(self):
        # Initialize the unified AI client
        self.ai_client = UnifiedAIClient()
        
        # Initialize RAG service for custom knowledge
        self.rag_service = RAGService(db_path="buddy_knowledge.db")
        
        # Initialize with default knowledge if database is empty
        asyncio.create_task(self._initialize_default_knowledge())
        
        # Advanced AI capabilities
        self.capabilities = {
            "code_generation": True,
            "project_analysis": True,
            "dynamic_templates": True,
            "context_awareness": True,
            "intelligent_reasoning": True,
            "multi_language_support": True,
            "real_time_adaptation": True
        }
    
    async def _initialize_default_knowledge(self):
        """Initialize default knowledge if database is empty"""
        try:
            stats = await self.rag_service.get_knowledge_stats()
            if stats['total_entries'] == 0:
                # Add some basic Buddy-specific knowledge
                default_knowledge = [
                    {
                        "title": "Buddy AI Assistant Overview",
                        "content": "Buddy is an intelligent AI assistant designed to help with project management, flow generation, note-taking, alarm setting, and various productivity tasks. It can understand complex requests and provide structured, actionable responses.",
                        "category": "system",
                        "tags": ["buddy", "ai", "assistant", "overview"],
                        "metadata": {
                            "source": "system_initialization",
                            "importance": "high",
                            "context_type": "reference"
                        }
                    },
                    {
                        "title": "Flow Generation Capabilities",
                        "content": "I can generate detailed project flows with checkpoints, timelines, and deliverables. I understand various project types including websites, mobile apps, business projects, AI/ML projects, and general software development.",
                        "category": "capabilities",
                        "tags": ["flows", "project-management", "capabilities"],
                        "metadata": {
                            "source": "system_initialization",
                            "importance": "high",
                            "context_type": "instruction"
                        }
                    }
                ]
                
                for knowledge in default_knowledge:
                    await self.rag_service.add_knowledge(knowledge)
        except Exception as e:
            print(f"Error initializing default knowledge: {e}")
    
    async def add_custom_knowledge(self, knowledge: Dict[str, Any]) -> str:
        """
        Add custom knowledge to enhance Buddy's responses
        
        Args:
            knowledge: Knowledge dictionary with required fields
            
        Returns:
            str: ID of the added knowledge entry
        """
        return await self.rag_service.add_knowledge(knowledge)
    
    async def get_relevant_context(self, query: str, limit: int = 3) -> List[Dict[str, Any]]:
        """Get relevant context from knowledge base for a query"""
        return await self.rag_service.get_relevant_context(query, limit)
    
    async def search_knowledge(self, query: str, category: Optional[str] = None) -> List[Dict[str, Any]]:
        """Search knowledge base"""
        return await self.rag_service.search_knowledge(query, category)
    
    async def list_knowledge(self, category: Optional[str] = None) -> List[Dict[str, Any]]:
        """List all knowledge entries"""
        return await self.rag_service.list_knowledge(category)
    
    async def get_user_context(self, user_id: str, db_session=None) -> Dict[str, Any]:
        """
        Get comprehensive user context from all app data
        This is like GitHub Copilot's understanding of your codebase
        """
        try:
            context = {
                "user_profile": {},
                "recent_activities": [],
                "preferences": {},
                "flows": [],
                "notes": [],
                "alarms": [],
                "personas": [],
                "knowledge_base": [],
                "usage_patterns": {},
                "technical_stack": [],
                "project_history": []
            }
            
            # Get user knowledge from RAG
            user_knowledge = await self.search_knowledge(f"user_id:{user_id}", None)
            context["knowledge_base"] = user_knowledge
            
            # TODO: Add actual database queries when db_session is provided
            if db_session:
                # This would fetch real data from database
                # context["flows"] = await get_user_flows(db_session, user_id)
                # context["notes"] = await get_user_notes(db_session, user_id)
                # context["alarms"] = await get_user_alarms(db_session, user_id)
                # context["personas"] = await get_user_personas(db_session, user_id)
                pass
            
            return context
            
        except Exception as e:
            print(f"Error getting user context: {e}")
            return {"error": "Could not retrieve user context"}
    
    async def analyze_user_intent_and_context(self, prompt: str, user_id: str, db_session=None) -> Dict[str, Any]:
        """
        Advanced intent analysis with full user context awareness
        Like GPT-5's understanding of user patterns and preferences
        """
        try:
            # Get user context
            user_context = await self.get_user_context(user_id, db_session)
            
            # Get relevant knowledge
            relevant_knowledge = await self.get_relevant_context(prompt, limit=5)
            
            # Create comprehensive analysis prompt
            analysis_prompt = f"""
Analyze this user request with full context awareness:

USER REQUEST: "{prompt}"

INTENT DETECTION RULES:
- If user asks to "generate code", "write code", "create code", "code for", "make program", "build app" → code_generation
- If user asks to "create flow", "build project", "project flow", "plan project" → flow_generation  
- Otherwise → question_answering

USER CONTEXT:
- Knowledge Base Entries: {len(user_context.get('knowledge_base', []))}
- Recent Activities: {user_context.get('recent_activities', [])}
- Active Flows: {len(user_context.get('flows', []))}
- Notes Count: {len(user_context.get('notes', []))}
- Preferred Tech Stack: {user_context.get('technical_stack', [])}

RELEVANT KNOWLEDGE:
{json.dumps(relevant_knowledge, indent=2) if relevant_knowledge else "None"}

Provide analysis in JSON format:
{{
    "intent_type": "flow_generation|code_generation|question_answering|task_management|system_control|github_operations",
    "confidence": 0.0-1.0,
    "user_context_relevance": "high|medium|low",
    "required_capabilities": ["list", "of", "required", "capabilities"],
    "project_type": "detected project type or null",
    "complexity_level": "beginner|intermediate|advanced|expert",
    "estimated_time": "time estimate",
    "personalization_factors": ["factors", "from", "user", "context"],
    "suggested_approach": "detailed approach based on user patterns",
    "code_generation_needed": boolean,
    "context_integration": "how to use user context"
}}

IMPORTANT: If the request contains words like "generate code for calculator" or similar, classify as code_generation with high confidence.
"""
            
            response = await self.ai_client.generate_response(analysis_prompt)
            
            # Parse AI response
            try:
                json_start = response.find('{')
                json_end = response.rfind('}') + 1
                if json_start != -1 and json_end != -1:
                    json_str = response[json_start:json_end]
                    analysis = json.loads(json_str)
                    analysis["user_context"] = user_context
                    analysis["relevant_knowledge"] = relevant_knowledge
                    return analysis
            except json.JSONDecodeError:
                pass
            
            # Fallback analysis
            return {
                "intent_type": "code_generation" if any(word in prompt.lower() for word in ['generate code', 'write code', 'create code', 'code for']) else "question_answering",
                "confidence": 0.8,
                "user_context_relevance": "medium",
                "user_context": user_context,
                "relevant_knowledge": relevant_knowledge,
                "raw_analysis": response
            }
            
        except Exception as e:
            print(f"Error in intent analysis: {e}")
            return {"error": str(e)}
    
    async def generate_intelligent_flow(self, 
                                      request: str, 
                                      user_context: Dict[str, Any],
                                      relevant_knowledge: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Generate flows intelligently like GitHub Copilot generates code
        Uses user context and knowledge to create personalized flows
        """
        try:
            # Create context-aware generation prompt
            generation_prompt = f"""
You are an advanced AI assistant like GitHub Copilot and GPT-5. Generate a comprehensive project flow based on the user's request and their personal context.

USER REQUEST: "{request}"

USER KNOWLEDGE & PREFERENCES:
{json.dumps(relevant_knowledge, indent=2) if relevant_knowledge else "No specific knowledge found"}

USER CONTEXT:
- Technical Stack: {user_context.get('technical_stack', [])}
- Recent Projects: {len(user_context.get('flows', []))} active flows
- Preferred Patterns: {user_context.get('preferences', {})}
- Experience Level: {user_context.get('usage_patterns', {})}

Generate a comprehensive flow in JSON format focused on timeline and progress tracking:
1. Dynamic timeline based on project complexity
2. Essential checkpoints with clear deliverables
3. AI help prompts for progress guidance
4. Clean structure for main flow screen

Response format:
{{
    "title": "Intelligent flow title",
    "description": "Context-aware description",
    "category": "detected category",
    "priority": "high|medium|low",
    "estimated_duration": "realistic estimate",
    "complexity_analysis": "detailed analysis",
    "sections": {{
        "timeline": {{
            "phases": [
                {{
                    "name": "Phase name",
                    "duration": "time estimate",
                    "tasks": [
                        {{
                            "task": "Specific task",
                            "type": "development|research|meeting|review",
                            "priority": "high|medium|low",
                            "estimated_time": "time",
                            "dependencies": ["dependency tasks"],
                            "resources_needed": ["resources"],
                            "code_generation": "if applicable",
                            "github_actions": "if needed",
                            "buddy_help_prompt": "AI guidance for this task"
                        }}
                    ]
                }}
            ]
        }}
    }},
    "success_metrics": [
        {{
            "metric": "Success measure",
            "target": "Specific target",
            "measurement_method": "How to measure"
        }}
    ],
    "resource_requirements": {{
        "technical": ["technical resources"],
        "human": ["human resources"],
        "tools": ["tools needed"],
        "knowledge": ["knowledge gaps to fill"]
    }},
    "integration_points": {{
        "github_repos": ["if applicable"],
        "system_commands": ["if needed"],
        "app_integrations": ["buddy app features to use"]
    }},
    "personalization": {{
        "based_on_user_preferences": "how this was personalized",
        "knowledge_base_usage": "how knowledge was applied",
        "pattern_matching": "user patterns considered"
    }}
}}

Make this flow intelligent and personalized, not generic. Use the user's context to make smart decisions about timing, complexity, and approach.
"""
            
            # Generate with AI
            response = await self.ai_client.generate_response(generation_prompt)
            
            # Parse AI response
            try:
                json_start = response.find('{')
                json_end = response.rfind('}') + 1
                if json_start != -1 and json_end != -1:
                    json_str = response[json_start:json_end]
                    flow_data = json.loads(json_str)
                    
                    # Add metadata
                    flow_data["generated_at"] = datetime.utcnow().isoformat()
                    flow_data["ai_generated"] = True
                    flow_data["generation_context"] = {
                        "user_request": request,
                        "knowledge_used": len(relevant_knowledge),
                        "context_factors": list(user_context.keys())
                    }
                    
                    return flow_data
            except json.JSONDecodeError as e:
                print(f"Error parsing AI response: {e}")
                return {"error": "Failed to parse AI response", "raw_response": response}
            
        except Exception as e:
            print(f"Error generating intelligent flow: {e}")
            return {"error": str(e)}
    
    async def generate_code_solution(self, 
                                   request: str, 
                                   user_context: Dict[str, Any],
                                   relevant_knowledge: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Generate code solutions like GitHub Copilot
        Context-aware code generation based on user's tech stack and patterns
        """
        try:
            # Extract technical context
            tech_stack = user_context.get('technical_stack', [])
            user_preferences = user_context.get('preferences', {})
            
            generation_prompt = f"""You are a helpful coding assistant like GitHub Copilot. Generate a complete code solution for this request:

REQUEST: "{request}"

USER'S TECHNICAL CONTEXT:
- Tech Stack: {tech_stack if tech_stack else ['Python', 'JavaScript']}
- Coding Preferences: {user_preferences if user_preferences else {'style': 'clean and readable'}}

KNOWLEDGE BASE CONTEXT:
{json.dumps(relevant_knowledge, indent=2) if relevant_knowledge else "No specific technical knowledge found"}

Create a practical, working code solution. For example, if they ask for a "calculator", provide actual calculator code.

Generate a complete solution in JSON format:
{{
    "solution_overview": "Brief explanation of what this code does",
    "primary_language": "Python or JavaScript or other appropriate language", 
    "complete_code": "Full working code that the user can run immediately",
    "explanation": "How the code works and key features",
    "usage_instructions": "How to run or use this code",
    "customization_tips": "How users can modify or extend it"
}}

Make the code practical and immediately usable. Focus on providing working code rather than complex architecture."""
            
            response = await self.ai_client.generate_response(generation_prompt)
            
            # Parse response
            try:
                json_start = response.find('{')
                json_end = response.rfind('}') + 1
                if json_start != -1 and json_end != -1:
                    json_str = response[json_start:json_end]
                    solution = json.loads(json_str)
                    
                    # Add metadata
                    solution["generated_at"] = datetime.utcnow().isoformat()
                    solution["ai_generated"] = True
                    solution["copilot_mode"] = True
                    
                    return solution
            except json.JSONDecodeError:
                print("Failed to parse JSON response, providing direct code solution")
                # If JSON parsing fails, provide a simple direct code solution
                return {
                    "solution_overview": f"Here's a code solution for: {request}",
                    "direct_code": response,
                    "technology_choices": {
                        "primary_language": "Python" if "python" in request.lower() else "JavaScript",
                        "rationale": "Popular and beginner-friendly language"
                    },
                    "raw_response": response
                }
            
        except Exception as e:
            print(f"Error generating code solution: {e}")
            return {"error": str(e), "solution_overview": "I encountered an error while generating the code solution. Let me try to help you with a simpler approach."}
    
    async def generate_project_flow(self, description: str, user_preferences: Optional[Dict] = None) -> Dict[str, Any]:
        """Generate an intelligent project flow using AI"""
        try:
            # Enhanced AI-powered flow generation
            prompt = f"""
You are an expert project manager. Create a detailed, actionable project timeline for: "{description}"

Generate a comprehensive project flow with this exact JSON structure:

{{
    "title": "Clear, descriptive project title",
    "difficulty": "easy|medium|hard|expert",
    "estimated_duration": "realistic timeframe (e.g., '2-3 weeks', '1 month')",
    "tags": ["relevant", "project", "tags"],
    "checkpoints": [
        {{
            "title": "Specific checkpoint name",
            "description": "Detailed, actionable description of what needs to be accomplished",
            "type": "task|milestone|review|testing",
            "estimated_time": "realistic time estimate",
            "requirements": ["specific prerequisites or resources needed"],
            "deliverables": ["concrete outputs or results"],
            "buddy_help_prompt": "Specific guidance I should provide at this checkpoint"
        }}
    ]
}}

Requirements:
- Include 6-10 comprehensive checkpoints
- Make each checkpoint specific and actionable
- Include realistic time estimates
- Add buddy_help_prompt for AI guidance at each step
- Consider dependencies between checkpoints
- Include testing, review, and launch phases
- Make deliverables concrete and measurable

Create a professional timeline for: {description}
"""

            response = await self.ai_client.generate_response(prompt)
            
            # Try to parse the JSON response
            try:
                # Clean the response to extract JSON
                json_start = response.find('{')
                json_end = response.rfind('}') + 1
                if json_start != -1 and json_end != -1:
                    json_str = response[json_start:json_end]
                    flow_data = json.loads(json_str)
                    
                    # Validate and enhance the generated flow
                    if self._validate_and_enhance_flow(flow_data):
                        return flow_data
                
                # If parsing fails, use intelligent templates
                return self._generate_intelligent_template(description)
                
            except json.JSONDecodeError:
                # Fallback to intelligent templates
                return self._generate_intelligent_template(description)
                
        except Exception as e:
            print(f"Error in AI flow generation: {e}")
            # Fallback to template-based generation
            return self._generate_intelligent_template(description)

    def _validate_and_enhance_flow(self, flow_data):
        """Validate and enhance the generated flow data"""
        try:
            # Check required fields
            required_fields = ['title', 'difficulty', 'estimated_duration', 'tags', 'checkpoints']
            if not all(field in flow_data for field in required_fields):
                return False
            
            # Validate checkpoints
            if not isinstance(flow_data['checkpoints'], list) or len(flow_data['checkpoints']) < 3:
                return False
                
            # Enhance each checkpoint
            for i, checkpoint in enumerate(flow_data['checkpoints']):
                # Ensure required checkpoint fields
                checkpoint_fields = ['title', 'description', 'type', 'estimated_time']
                if not all(field in checkpoint for field in checkpoint_fields):
                    return False
                
                # Add buddy_help_prompt if missing
                if 'buddy_help_prompt' not in checkpoint:
                    checkpoint['buddy_help_prompt'] = f"I'm here to help you with {checkpoint['title']}. Let me know what specific guidance you need!"
                
                # Ensure requirements and deliverables are lists
                if 'requirements' not in checkpoint:
                    checkpoint['requirements'] = ["Previous checkpoint completion"]
                if 'deliverables' not in checkpoint:
                    checkpoint['deliverables'] = [f"Completed {checkpoint['title']}"]
                    
            return True
            
        except Exception as e:
            print(f"Error validating flow: {e}")
            return False

    def _generate_intelligent_template(self, description: str):
        """Generate intelligent templates based on project type detection"""
        description_lower = description.lower()
        
        # Detect project type
        project_type = self._detect_enhanced_project_type(description_lower)
        
        # Generate customized templates
        if project_type == "website":
            return self._create_website_flow_template(description)
        elif project_type == "mobile_app":
            return self._create_mobile_app_flow_template(description)
        elif project_type == "business":
            return self._create_business_flow_template(description)
        elif project_type == "software":
            return self._create_software_flow_template(description)
        elif project_type == "ecommerce":
            return self._create_ecommerce_flow_template(description)
        elif project_type == "ai_ml":
            return self._create_ai_ml_flow_template(description)
        else:
            return self._create_general_flow_template(description)

    def _detect_enhanced_project_type(self, description: str):
        """Enhanced project type detection"""
        # Website/Web Development
        if any(word in description for word in ['website', 'web', 'frontend', 'backend', 'html', 'css', 'javascript', 'react', 'vue', 'angular', 'landing page', 'portfolio']):
            return "website"
        
        # E-commerce
        if any(word in description for word in ['ecommerce', 'e-commerce', 'online store', 'shop', 'marketplace', 'payment', 'cart', 'checkout']):
            return "ecommerce"
        
        # Mobile App Development
        if any(word in description for word in ['app', 'mobile', 'android', 'ios', 'flutter', 'react native', 'swift', 'kotlin']):
            return "mobile_app"
        
        # AI/ML Projects
        if any(word in description for word in ['ai', 'artificial intelligence', 'machine learning', 'ml', 'neural network', 'deep learning', 'chatbot', 'nlp']):
            return "ai_ml"
        
        # Software Development
        if any(word in description for word in ['software', 'system', 'application', 'program', 'code', 'development', 'api', 'database']):
            return "software"
        
        # Business Projects
        if any(word in description for word in ['business', 'company', 'startup', 'strategy', 'plan', 'marketing', 'sales', 'launch']):
            return "business"
        
        return "general"

    def _create_website_flow_template(self, description: str):
        """Create comprehensive website development flow"""
        return {
            "title": f"Website Development: {self._extract_project_name(description)}",
            "difficulty": "medium",
            "estimated_duration": "3-4 weeks",
            "tags": ["website", "development", "web", "frontend"],
            "checkpoints": [
                {
                    "title": "Project Planning & Requirements",
                    "description": "Define website goals, target audience, features, and create detailed project roadmap",
                    "type": "milestone",
                    "estimated_time": "2-3 days",
                    "requirements": ["Project brief", "Business goals"],
                    "deliverables": ["Requirements document", "Site map", "Feature list", "Timeline"],
                    "buddy_help_prompt": "I'll help you define clear website requirements. Let's discuss your target audience, main goals, and key features you need."
                },
                {
                    "title": "UI/UX Design & Wireframing",
                    "description": "Create wireframes, user flow, and visual design mockups for all pages",
                    "type": "task",
                    "estimated_time": "4-5 days",
                    "requirements": ["Requirements document", "Design tools", "Brand guidelines"],
                    "deliverables": ["Wireframes", "Visual mockups", "Style guide", "User flow diagrams"],
                    "buddy_help_prompt": "Let's create effective designs! I can suggest layout patterns, color schemes, typography, and help with user experience optimization."
                },
                {
                    "title": "Frontend Development Setup",
                    "description": "Set up development environment, choose tech stack, and create project structure",
                    "type": "task",
                    "estimated_time": "1-2 days",
                    "requirements": ["Design approval", "Development tools"],
                    "deliverables": ["Project setup", "Development environment", "Basic structure"],
                    "buddy_help_prompt": "I'll guide you through frontend setup. Need help choosing between React, Vue, vanilla JS, or setting up your development environment?"
                },
                {
                    "title": "Frontend Implementation",
                    "description": "Code responsive HTML/CSS/JavaScript based on approved designs",
                    "type": "task",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Setup completion", "Design assets"],
                    "deliverables": ["Responsive layout", "Interactive features", "Cross-browser compatibility"],
                    "buddy_help_prompt": "Let's build your frontend! I can help with responsive design, CSS frameworks, JavaScript functionality, and performance optimization."
                },
                {
                    "title": "Backend Development",
                    "description": "Create server, database, APIs, and backend functionality",
                    "type": "task",
                    "estimated_time": "5-7 days",
                    "requirements": ["Frontend foundation", "Server hosting"],
                    "deliverables": ["Server setup", "Database schema", "API endpoints", "Authentication"],
                    "buddy_help_prompt": "Backend development time! I'll help with server setup, database design, API creation, and choosing the right technology stack."
                },
                {
                    "title": "Content Integration & SEO",
                    "description": "Add content, optimize for search engines, and implement analytics",
                    "type": "task",
                    "estimated_time": "3-4 days",
                    "requirements": ["Website structure", "Content materials"],
                    "deliverables": ["Content integration", "SEO optimization", "Analytics setup", "Meta tags"],
                    "buddy_help_prompt": "Let's optimize your content! I'll help with SEO best practices, content structure, image optimization, and analytics implementation."
                },
                {
                    "title": "Testing & Quality Assurance",
                    "description": "Comprehensive testing across devices, browsers, and performance optimization",
                    "type": "testing",
                    "estimated_time": "3-4 days",
                    "requirements": ["Complete website", "Testing devices"],
                    "deliverables": ["Test results", "Bug fixes", "Performance optimizations", "Security checks"],
                    "buddy_help_prompt": "Testing phase! I'll guide you through cross-browser testing, mobile responsiveness, performance optimization, and security best practices."
                },
                {
                    "title": "Deployment & Launch",
                    "description": "Deploy to production, set up domain, SSL, and launch the website",
                    "type": "review",
                    "estimated_time": "2-3 days",
                    "requirements": ["Tested website", "Hosting account", "Domain"],
                    "deliverables": ["Live website", "SSL certificate", "Domain setup", "Launch checklist"],
                    "buddy_help_prompt": "Launch time! I'll help with hosting setup, domain configuration, SSL certificates, and creating a successful launch strategy."
                }
            ]
        }
    
    def _create_mobile_app_flow_template(self, description: str):
        """Create comprehensive mobile app development flow"""
        return {
            "title": f"Mobile App Development: {self._extract_project_name(description)}",
            "difficulty": "hard",
            "estimated_duration": "6-8 weeks",
            "tags": ["mobile", "app", "development", "ios", "android"],
            "checkpoints": [
                {
                    "title": "App Concept & Market Research",
                    "description": "Define app concept, analyze competitors, and validate market demand",
                    "type": "milestone",
                    "estimated_time": "3-4 days",
                    "requirements": ["App idea", "Target audience"],
                    "deliverables": ["Market research report", "App concept document", "Competitor analysis"],
                    "buddy_help_prompt": "Let's validate your app idea! I'll help you research the market, analyze competitors, and refine your concept."
                },
                {
                    "title": "Technical Planning & Architecture",
                    "description": "Choose technology stack, plan app architecture, and create technical specifications",
                    "type": "task",
                    "estimated_time": "3-4 days",
                    "requirements": ["App concept", "Platform decision"],
                    "deliverables": ["Tech stack selection", "Architecture diagram", "Database design"],
                    "buddy_help_prompt": "Time to plan the technical foundation! I'll help you choose between native, hybrid, or cross-platform development and design the architecture."
                },
                {
                    "title": "UI/UX Design & Prototyping",
                    "description": "Create user interface designs, user flows, and interactive prototypes",
                    "type": "task",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["User research", "Design tools"],
                    "deliverables": ["UI mockups", "User flow diagrams", "Interactive prototype", "Design system"],
                    "buddy_help_prompt": "Let's create an amazing user experience! I'll guide you through mobile design patterns, accessibility, and creating engaging interfaces."
                },
                {
                    "title": "Development Environment Setup",
                    "description": "Set up development tools, project structure, and development workflow",
                    "type": "task",
                    "estimated_time": "2-3 days",
                    "requirements": ["Tech stack decision", "Development tools"],
                    "deliverables": ["Project setup", "Development environment", "CI/CD pipeline"],
                    "buddy_help_prompt": "Let's set up your development environment! I'll help with IDE setup, emulators, version control, and project structure."
                },
                {
                    "title": "Core Features Development",
                    "description": "Implement main app features, navigation, and core functionality",
                    "type": "task",
                    "estimated_time": "3-4 weeks",
                    "requirements": ["Setup completion", "Design assets"],
                    "deliverables": ["Core features", "Navigation system", "User authentication", "Data management"],
                    "buddy_help_prompt": "Development phase! I'll help you implement features, handle navigation, manage state, and integrate APIs effectively."
                },
                {
                    "title": "Testing & Debugging",
                    "description": "Comprehensive testing on multiple devices and platforms",
                    "type": "testing",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Feature completion", "Test devices"],
                    "deliverables": ["Test suite", "Bug fixes", "Performance optimization", "Device compatibility"],
                    "buddy_help_prompt": "Testing time! I'll guide you through unit testing, integration testing, device testing, and performance optimization."
                },
                {
                    "title": "App Store Preparation",
                    "description": "Prepare app store listings, screenshots, and metadata",
                    "type": "task",
                    "estimated_time": "3-4 days",
                    "requirements": ["Tested app", "Marketing materials"],
                    "deliverables": ["App store listing", "Screenshots", "App description", "Keywords"],
                    "buddy_help_prompt": "App store optimization! I'll help you create compelling listings, choose the right keywords, and prepare marketing materials."
                },
                {
                    "title": "Launch & Marketing",
                    "description": "Submit to app stores and execute launch marketing strategy",
                    "type": "review",
                    "estimated_time": "1 week",
                    "requirements": ["App store materials", "Marketing plan"],
                    "deliverables": ["Published app", "Launch campaign", "User acquisition strategy"],
                    "buddy_help_prompt": "Launch day! I'll help you submit to app stores, track metrics, and execute your marketing strategy for maximum impact."
                }
            ]
        }

    def _create_ecommerce_flow_template(self, description: str):
        """Create comprehensive e-commerce development flow"""
        return {
            "title": f"E-commerce Store: {self._extract_project_name(description)}",
            "difficulty": "hard",
            "estimated_duration": "4-6 weeks",
            "tags": ["ecommerce", "online store", "business", "sales"],
            "checkpoints": [
                {
                    "title": "Business Planning & Strategy",
                    "description": "Define business model, target market, and e-commerce strategy",
                    "type": "milestone",
                    "estimated_time": "3-4 days",
                    "requirements": ["Business idea", "Market research"],
                    "deliverables": ["Business plan", "Target audience analysis", "Competitive analysis"],
                    "buddy_help_prompt": "Let's build your e-commerce strategy! I'll help you define your target market, pricing strategy, and business model."
                },
                {
                    "title": "Platform Selection & Setup",
                    "description": "Choose e-commerce platform and set up basic store structure",
                    "type": "task",
                    "estimated_time": "2-3 days",
                    "requirements": ["Business requirements", "Budget planning"],
                    "deliverables": ["Platform selection", "Store setup", "Basic configuration"],
                    "buddy_help_prompt": "Platform decision time! I'll help you choose between Shopify, WooCommerce, Magento, or custom development based on your needs."
                },
                {
                    "title": "Store Design & Branding",
                    "description": "Create store design, branding, and user experience flow",
                    "type": "task",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Platform setup", "Brand guidelines"],
                    "deliverables": ["Store design", "Brand identity", "User journey mapping"],
                    "buddy_help_prompt": "Let's create a compelling store design! I'll help with layout, branding, product showcase, and conversion optimization."
                },
                {
                    "title": "Product Catalog Setup",
                    "description": "Add products, categories, pricing, and inventory management",
                    "type": "task",
                    "estimated_time": "1 week",
                    "requirements": ["Product information", "High-quality images"],
                    "deliverables": ["Product catalog", "Category structure", "Pricing setup", "Inventory system"],
                    "buddy_help_prompt": "Product catalog time! I'll help you organize categories, write compelling descriptions, optimize images, and set up inventory tracking."
                },
                {
                    "title": "Payment & Security Setup",
                    "description": "Implement payment gateways, security features, and compliance",
                    "type": "task",
                    "estimated_time": "3-4 days",
                    "requirements": ["Business accounts", "SSL certificate"],
                    "deliverables": ["Payment integration", "Security setup", "SSL installation", "Compliance checks"],
                    "buddy_help_prompt": "Security and payments! I'll guide you through payment gateway setup, SSL certificates, PCI compliance, and fraud protection."
                },
                {
                    "title": "Testing & Optimization",
                    "description": "Test all store functions, optimize for conversions and performance",
                    "type": "testing",
                    "estimated_time": "1 week",
                    "requirements": ["Complete store setup", "Test orders"],
                    "deliverables": ["Functionality testing", "Performance optimization", "Conversion rate optimization"],
                    "buddy_help_prompt": "Testing phase! I'll help you test the entire purchase flow, optimize loading speeds, and improve conversion rates."
                },
                {
                    "title": "Launch & Marketing",
                    "description": "Launch store and implement marketing strategies",
                    "type": "review",
                    "estimated_time": "1 week",
                    "requirements": ["Tested store", "Marketing materials"],
                    "deliverables": ["Live store", "SEO optimization", "Marketing campaigns", "Analytics setup"],
                    "buddy_help_prompt": "Launch time! I'll help you go live, set up analytics, create marketing campaigns, and drive your first sales."
                }
            ]
        }

    def _create_ai_ml_flow_template(self, description: str):
        """Create AI/ML project development flow"""
        return {
            "title": f"AI/ML Project: {self._extract_project_name(description)}",
            "difficulty": "expert",
            "estimated_duration": "8-12 weeks",
            "tags": ["ai", "machine learning", "data science", "python"],
            "checkpoints": [
                {
                    "title": "Problem Definition & Research",
                    "description": "Define AI problem, research existing solutions, and validate approach",
                    "type": "milestone",
                    "estimated_time": "1 week",
                    "requirements": ["Problem statement", "Domain knowledge"],
                    "deliverables": ["Problem definition", "Literature review", "Approach validation"],
                    "buddy_help_prompt": "Let's define your AI problem clearly! I'll help you research existing solutions, choose the right approach, and set realistic goals."
                },
                {
                    "title": "Data Collection & Analysis",
                    "description": "Gather, clean, and analyze data for training and testing",
                    "type": "task",
                    "estimated_time": "2-3 weeks",
                    "requirements": ["Data sources", "Data collection tools"],
                    "deliverables": ["Dataset", "Data analysis report", "Data quality assessment"],
                    "buddy_help_prompt": "Data is crucial! I'll help you find data sources, clean datasets, handle missing values, and perform exploratory data analysis."
                },
                {
                    "title": "Model Development & Training",
                    "description": "Design, implement, and train machine learning models",
                    "type": "task",
                    "estimated_time": "3-4 weeks",
                    "requirements": ["Processed data", "Computing resources"],
                    "deliverables": ["Trained models", "Training metrics", "Model comparison"],
                    "buddy_help_prompt": "Model building time! I'll guide you through algorithm selection, hyperparameter tuning, and training optimization."
                },
                {
                    "title": "Model Evaluation & Validation",
                    "description": "Test model performance, validate results, and optimize accuracy",
                    "type": "testing",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Trained models", "Test data"],
                    "deliverables": ["Performance metrics", "Validation results", "Model optimization"],
                    "buddy_help_prompt": "Evaluation phase! I'll help you assess model performance, handle overfitting, and improve accuracy using proper validation techniques."
                },
                {
                    "title": "Deployment Preparation",
                    "description": "Prepare model for production deployment and create APIs",
                    "type": "task",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Validated model", "Deployment platform"],
                    "deliverables": ["Production model", "API endpoints", "Documentation"],
                    "buddy_help_prompt": "Deployment prep! I'll help you containerize your model, create APIs, and prepare for production deployment."
                },
                {
                    "title": "Production Deployment",
                    "description": "Deploy model to production and set up monitoring",
                    "type": "review",
                    "estimated_time": "1 week",
                    "requirements": ["Production-ready model", "Infrastructure"],
                    "deliverables": ["Live model", "Monitoring setup", "Performance tracking"],
                    "buddy_help_prompt": "Going live! I'll help you deploy to cloud platforms, set up monitoring, and ensure your AI model performs well in production."
                }
            ]
        }

    def _create_business_flow_template(self, description: str):
        """Create business project development flow"""
        return {
            "title": f"Business Project: {self._extract_project_name(description)}",
            "difficulty": "medium",
            "estimated_duration": "4-6 weeks",
            "tags": ["business", "strategy", "planning", "launch"],
            "checkpoints": [
                {
                    "title": "Market Research & Analysis",
                    "description": "Conduct comprehensive market research and competitive analysis",
                    "type": "milestone",
                    "estimated_time": "1 week",
                    "requirements": ["Business idea", "Research tools"],
                    "deliverables": ["Market research report", "Competitive analysis", "SWOT analysis"],
                    "buddy_help_prompt": "Let's research your market! I'll help you analyze competitors, identify opportunities, and validate your business idea."
                },
                {
                    "title": "Business Plan Development",
                    "description": "Create comprehensive business plan with financial projections",
                    "type": "task",
                    "estimated_time": "2 weeks",
                    "requirements": ["Market research", "Financial data"],
                    "deliverables": ["Business plan", "Financial projections", "Risk assessment"],
                    "buddy_help_prompt": "Business planning time! I'll guide you through creating financial projections, defining your business model, and risk planning."
                },
                {
                    "title": "Brand Development & Marketing Strategy",
                    "description": "Develop brand identity and comprehensive marketing strategy",
                    "type": "task",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Brand concept", "Target audience"],
                    "deliverables": ["Brand identity", "Marketing strategy", "Brand guidelines"],
                    "buddy_help_prompt": "Let's build your brand! I'll help you create a compelling brand identity, develop messaging, and plan your marketing strategy."
                },
                {
                    "title": "Product/Service Development",
                    "description": "Develop minimum viable product or service offering",
                    "type": "task",
                    "estimated_time": "2-3 weeks",
                    "requirements": ["Business plan", "Resources"],
                    "deliverables": ["MVP", "Service framework", "Quality standards"],
                    "buddy_help_prompt": "Product development! I'll help you create your MVP, define service standards, and ensure quality delivery."
                },
                {
                    "title": "Operations & Systems Setup",
                    "description": "Set up business operations, systems, and processes",
                    "type": "task",
                    "estimated_time": "1 week",
                    "requirements": ["Business structure", "Technology needs"],
                    "deliverables": ["Operational processes", "System setup", "Documentation"],
                    "buddy_help_prompt": "Operations setup! I'll help you establish efficient processes, choose the right tools, and create systematic workflows."
                },
                {
                    "title": "Launch Preparation & Marketing",
                    "description": "Prepare for launch and execute marketing campaigns",
                    "type": "review",
                    "estimated_time": "1-2 weeks",
                    "requirements": ["Complete setup", "Marketing materials"],
                    "deliverables": ["Launch plan", "Marketing campaigns", "Customer acquisition"],
                    "buddy_help_prompt": "Launch time! I'll help you execute your launch strategy, run marketing campaigns, and acquire your first customers."
                }
            ]
        }

    def _create_software_flow_template(self, description: str):
        """Create general software development flow"""
        return {
            "title": f"Software Project: {self._extract_project_name(description)}",
            "difficulty": "medium",
            "estimated_duration": "4-6 weeks",
            "tags": ["software", "development", "programming"],
            "checkpoints": [
                {
                    "title": "Requirements Analysis & Planning",
                    "description": "Gather requirements, analyze scope, and create project plan",
                    "type": "milestone",
                    "estimated_time": "3-5 days",
                    "requirements": ["Project brief", "Stakeholder input"],
                    "deliverables": ["Requirements document", "Project scope", "Timeline"],
                    "buddy_help_prompt": "Let's plan your software project! I'll help you gather requirements, define scope, and create a realistic timeline."
                },
                {
                    "title": "System Architecture & Design",
                    "description": "Design system architecture, database, and technical specifications",
                    "type": "task",
                    "estimated_time": "1 week",
                    "requirements": ["Requirements", "Technology preferences"],
                    "deliverables": ["Architecture diagram", "Database design", "Technical specs"],
                    "buddy_help_prompt": "Architecture design! I'll help you choose the right technologies, design scalable architecture, and plan your database."
                },
                {
                    "title": "Development Environment Setup",
                    "description": "Set up development tools, version control, and project structure",
                    "type": "task",
                    "estimated_time": "1-2 days",
                    "requirements": ["Tech stack decision", "Development tools"],
                    "deliverables": ["Project setup", "Development environment", "Version control"],
                    "buddy_help_prompt": "Environment setup! I'll guide you through setting up your development environment, version control, and project structure."
                },
                {
                    "title": "Core Development",
                    "description": "Implement core functionality and main features",
                    "type": "task",
                    "estimated_time": "2-3 weeks",
                    "requirements": ["Setup completion", "Design specifications"],
                    "deliverables": ["Core functionality", "Main features", "API endpoints"],
                    "buddy_help_prompt": "Development phase! I'll help you implement features efficiently, follow best practices, and write clean, maintainable code."
                },
                {
                    "title": "Testing & Quality Assurance",
                    "description": "Comprehensive testing, debugging, and code quality improvement",
                    "type": "testing",
                    "estimated_time": "1 week",
                    "requirements": ["Feature completion", "Testing framework"],
                    "deliverables": ["Test suite", "Bug fixes", "Code quality report"],
                    "buddy_help_prompt": "Testing time! I'll help you write effective tests, debug issues, and ensure code quality and reliability."
                },
                {
                    "title": "Deployment & Documentation",
                    "description": "Deploy to production and create comprehensive documentation",
                    "type": "review",
                    "estimated_time": "3-5 days",
                    "requirements": ["Tested software", "Deployment platform"],
                    "deliverables": ["Production deployment", "User documentation", "Technical documentation"],
                    "buddy_help_prompt": "Final phase! I'll help you deploy to production, create clear documentation, and ensure smooth operation."
                }
            ]
        }

    def _create_general_flow_template(self, description: str):
        """Create general project flow for unrecognized types"""
        return {
            "title": f"Project: {self._extract_project_name(description)}",
            "difficulty": "medium",
            "estimated_duration": "2-4 weeks",
            "tags": ["project", "general", "custom"],
            "checkpoints": [
                {
                    "title": "Project Planning & Research",
                    "description": "Define project goals, research requirements, and create action plan",
                    "type": "milestone",
                    "estimated_time": "2-3 days",
                    "requirements": ["Project concept", "Goals definition"],
                    "deliverables": ["Project plan", "Research findings", "Success metrics"],
                    "buddy_help_prompt": "I'll help you define clear project goals and research requirements. Let's create an actionable plan!"
                },
                {
                    "title": "Resource Gathering & Preparation",
                    "description": "Gather necessary resources, tools, and materials for the project",
                    "type": "task",
                    "estimated_time": "2-4 days",
                    "requirements": ["Project plan", "Resource identification"],
                    "deliverables": ["Resource list", "Tool setup", "Material preparation"],
                    "buddy_help_prompt": "I'll assist you in identifying and gathering all the resources you'll need for this project."
                },
                {
                    "title": "Implementation Phase 1",
                    "description": "Begin project implementation with foundational work",
                    "type": "task",
                    "estimated_time": "1 week",
                    "requirements": ["Preparation completion", "Resources available"],
                    "deliverables": ["Foundation work", "Initial progress", "Milestone achievements"],
                    "buddy_help_prompt": "Let's get started with the implementation! I'll guide you through the initial steps."
                },
                {
                    "title": "Implementation Phase 2",
                    "description": "Continue development and refine the project outcomes",
                    "type": "task",
                    "estimated_time": "1 week",
                    "requirements": ["Phase 1 completion", "Feedback incorporation"],
                    "deliverables": ["Advanced progress", "Refined outputs", "Quality improvements"],
                    "buddy_help_prompt": "Continuing progress! I'll help you refine your work, incorporate feedback, and maintain quality standards."
                },
                {
                    "title": "Testing & Review",
                    "description": "Test project outcomes, review quality, and make necessary adjustments",
                    "type": "testing",
                    "estimated_time": "2-3 days",
                    "requirements": ["Implementation completion", "Review criteria"],
                    "deliverables": ["Test results", "Quality review", "Improvement recommendations"],
                    "buddy_help_prompt": "Review time! I'll help you evaluate your work, identify improvements, and ensure you meet your project goals."
                },
                {
                    "title": "Finalization & Delivery",
                    "description": "Finalize project, prepare deliverables, and complete handover",
                    "type": "review",
                    "estimated_time": "1-2 days",
                    "requirements": ["Review completion", "Final adjustments"],
                    "deliverables": ["Final project", "Documentation", "Delivery package"],
                    "buddy_help_prompt": "Final stretch! I'll help you finalize everything, prepare deliverables, and ensure successful project completion."
                }
            ]
        }

    def _extract_project_name(self, description: str):
        """Extract a clean project name from description"""
        # Remove common flow trigger words
        clean_desc = description.lower()
        for trigger in ['create flow for', 'generate flow for', 'flow:', 'create', 'generate', 'flow']:
            clean_desc = clean_desc.replace(trigger, '').strip()
        
        # Take first few words and capitalize
        words = clean_desc.split()[:3]
        return ' '.join(word.capitalize() for word in words) if words else "Custom Project"
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
        message_lower = message.lower().strip()
        
        # Very specific flow trigger phrases - must be explicit
        flow_triggers = [
            "create flow for", "generate flow for", "flow:", "make a flow for",
            "create project flow", "generate project flow", "new flow for"
        ]
        
        # Check for explicit flow creation requests only
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
            
            # Make sure we have a meaningful description
            if len(description.strip()) < 3:
                return {
                    "is_flow_request": False,
                    "project_description": "",
                    "confidence": 0.0
                }
            
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

    async def generate_ai_response(self, prompt: str, user_id: str = None, db_session=None, chat_history: List[Dict[str, str]] = None) -> Dict[str, Any]:
        """
        Enhanced AI response generation with RAG integration and intelligent routing
        Works like GPT-5 with full context awareness and GitHub Copilot capabilities
        """
        try:
            print(f"Processing intelligent request: {prompt}")
            
            # Handle simple greetings and small talk quickly
            if self._is_simple_greeting(prompt):
                return await self._generate_simple_response(prompt)
            
            # For everything else, use natural ChatGPT-like intelligence without over-analysis
            # Only do heavy analysis for clearly complex requests
            code_keywords = ['generate code', 'write code', 'create code', 'code for', 'build app', 'make program', 'programming', 'script', 'function']
            flow_keywords = ['create flow', 'build project', 'project flow', 'make flow', 'develop project', 'plan project']
            
            prompt_lower = prompt.lower()
            is_code_request = any(keyword in prompt_lower for keyword in code_keywords)
            is_flow_request = any(keyword in prompt_lower for keyword in flow_keywords)
            
            if is_code_request or is_flow_request:
                # Get comprehensive context if user_id provided
                user_context = {}
                if user_id:
                    user_context = await self.get_user_context(user_id, db_session)
                
                # Analyze intent with full context for complex requests
                intent_analysis = await self.analyze_user_intent_and_context(prompt, user_id or "anonymous", db_session)
                
                # Get relevant knowledge from RAG
                relevant_knowledge = intent_analysis.get('relevant_knowledge', [])
                
                # Route to appropriate handler based on intelligent analysis
                intent_type = intent_analysis.get('intent_type', 'question_answering')
                
                # Override intent type if we clearly detected code or flow requests
                if is_code_request:
                    intent_type = 'code_generation'
                elif is_flow_request:
                    intent_type = 'flow_generation'
                
                if intent_type == 'flow_generation':
                    # Generate intelligent flow
                    flow_result = await self.generate_intelligent_flow(prompt, user_context, relevant_knowledge)
                    return {
                        "type": "flow",
                        "content": flow_result,
                        "intent_analysis": intent_analysis,
                        "ai_mode": "intelligent_flow_generation",
                        "context_used": len(relevant_knowledge) > 0
                    }
                    
                elif intent_type == 'code_generation':
                    # Generate code solution like GitHub Copilot
                    try:
                        code_result = await self.generate_code_solution(prompt, user_context, relevant_knowledge)
                        return {
                            "type": "code_solution",
                            "content": code_result,
                            "intent_analysis": intent_analysis,
                            "ai_mode": "github_copilot_mode",
                            "context_used": len(relevant_knowledge) > 0
                        }
                    except Exception as e:
                        print(f"Error in code generation: {e}")
                        # Fallback to simple code generation
                        return {
                            "type": "enhanced_response",
                            "content": {
                                "direct_answer": f"I'll help you create code for {prompt.replace('generate code for', '').replace('create code for', '').strip()}. Let me provide a solution...",
                                "response_type": "code_fallback"
                            },
                            "ai_mode": "code_generation_fallback",
                            "context_used": False
                        }
            
            # For normal questions, respond naturally like ChatGPT without heavy analysis
            user_context = {}
            if user_id:
                user_context = await self.get_user_context(user_id, db_session)
            
            # Get some relevant knowledge but don't over-analyze
            relevant_knowledge = await self.get_relevant_context(prompt, limit=2)
            
            # Simple intent analysis - just determine complexity
            intent_analysis = {
                "intent_type": "question_answering",
                "confidence": 0.9,
                "complexity_level": "medium" if len(prompt.split()) > 10 else "beginner"
            }
            
            # Generate natural, context-aware response
            context_enhanced_response = await self.generate_context_aware_response(
                prompt, user_context, relevant_knowledge, intent_analysis, chat_history=chat_history
            )
            return {
                "type": "enhanced_response",
                "content": context_enhanced_response,
                "ai_mode": "natural_chatgpt",
                "context_used": len(relevant_knowledge) > 0
            }
                
        except Exception as e:
            print(f"Error in enhanced AI response: {e}")
            return {
                "type": "error",
                "content": {"error": str(e)},
                "ai_mode": "fallback"
            }
    
    async def generate_context_aware_response(self, 
                                            prompt: str,
                                            user_context: Dict[str, Any],
                                            relevant_knowledge: List[Dict[str, Any]],
                                            intent_analysis: Dict[str, Any],
                                            chat_history: List[Dict[str, str]] = None) -> Dict[str, Any]:
        """
        Generate natural, ChatGPT-like responses that adapt to complexity
        Simple questions get simple answers, complex ones get detailed responses
        """
        try:
            # Determine response complexity based on prompt and intent
            complexity_level = intent_analysis.get('complexity_level', 'medium')
            prompt_length = len(prompt.split())
            
            # For simple questions (like ChatGPT), provide concise, direct responses
            if complexity_level == 'beginner' or prompt_length < 10:
                # Simple, conversational response
                simple_prompt = f"""
You are Buddy, a helpful AI assistant. Respond naturally and conversationally to this question.

User: {prompt}

Context: {json.dumps(relevant_knowledge[:2], indent=2) if relevant_knowledge else "No specific context"}

Provide a helpful, natural response. Be conversational, not formal. Give exactly what the user needs - short for simple questions, detailed for complex ones.
"""
                
                response = await self.ai_client.generate_response(simple_prompt, chat_history=chat_history)
                
                return {
                    "direct_answer": response,
                    "response_type": "conversational",
                    "context_used": len(relevant_knowledge) > 0
                }
            
            # For more complex questions, provide structured but natural responses
            else:
                enhanced_prompt = f"""
You are Buddy, an advanced AI assistant. The user asked: "{prompt}"

Available context: {json.dumps(relevant_knowledge, indent=2) if relevant_knowledge else "No specific context"}

User's background: {user_context.get('technical_stack', [])} technical experience

Respond naturally and helpfully. Structure your response appropriately:
- For simple questions: Give direct, concise answers
- For complex questions: Provide detailed explanations with examples
- Always be conversational and helpful, not robotic

Focus on being genuinely helpful rather than following rigid formats.
"""
                
                response = await self.ai_client.generate_response(enhanced_prompt, chat_history=chat_history)
                
                # Check if the response warrants additional structure
                if any(keyword in prompt.lower() for keyword in ['how to', 'steps', 'guide', 'tutorial', 'implement']):
                    # For how-to questions, add some structure
                    return {
                        "direct_answer": response,
                        "response_type": "instructional",
                        "context_used": len(relevant_knowledge) > 0,
                        "follow_up_available": True
                    }
                else:
                    # For general questions, keep it simple
                    return {
                        "direct_answer": response,
                        "response_type": "conversational",
                        "context_used": len(relevant_knowledge) > 0
                    }
                
        except Exception as e:
            print(f"Error generating context-aware response: {e}")
            return {"direct_answer": "I'd be happy to help! Could you tell me a bit more about what you're looking for?", "error": str(e)}
    
    async def generate_persona_response(
        self, 
        prompt: str, 
        persona=None, 
        chat_history: List[Dict[str, str]] = None
    ) -> str:
        """Generate AI response with persona context"""
        try:
            # If no persona is provided, use default Buddy behavior
            if not persona:
                return await self.generate_ai_response(prompt, chat_history)
            
            # Create persona-specific system prompt
            persona_system_prompt = self._build_persona_system_prompt(persona)
            
            # Build conversation with persona context
            conversation_history = chat_history or []
            
            # Add persona context to the beginning if this is the first interaction
            if not conversation_history or len(conversation_history) == 0:
                enhanced_prompt = f"{persona_system_prompt}\n\nUser: {prompt}"
            else:
                # For ongoing conversations, just add the current prompt
                enhanced_prompt = prompt
            
            # Generate response using the AI client
            response = await self.ai_client.generate_response(enhanced_prompt, conversation_history)
            
            # Post-process response to ensure persona consistency
            return self._enhance_persona_response(response, persona)
            
        except Exception as e:
            print(f"Error generating persona response: {e}")
            # Fallback to regular response
            return await self.generate_ai_response(prompt, chat_history)
    
    def _build_persona_system_prompt(self, persona) -> str:
        """Build system prompt based on persona"""
        if not persona:
            return ""
        
        # Use custom system prompt if available
        if persona.system_prompt:
            return persona.system_prompt
        
        # Build system prompt from persona attributes
        base_prompt = f"You are {persona.name}."
        
        if persona.description:
            base_prompt += f" {persona.description}"
        
        # Add personality traits
        if persona.personality_traits:
            try:
                import json
                traits = json.loads(persona.personality_traits)
                if traits:
                    traits_str = ", ".join(traits)
                    base_prompt += f" Your key personality traits are: {traits_str}."
            except (json.JSONDecodeError, AttributeError):
                # If JSON parsing fails, use as string
                if isinstance(persona.personality_traits, str):
                    base_prompt += f" Your personality: {persona.personality_traits}."
        
        # Add expertise areas
        if persona.expertise_areas:
            try:
                import json
                expertise = json.loads(persona.expertise_areas)
                if expertise:
                    expertise_str = ", ".join(expertise)
                    base_prompt += f" Your areas of expertise include: {expertise_str}."
            except (json.JSONDecodeError, AttributeError):
                if isinstance(persona.expertise_areas, str):
                    base_prompt += f" Your expertise: {persona.expertise_areas}."
        
        # Add response style guidance
        response_style = persona.response_style or "conversational"
        style_guidance = {
            "formal": "Use a professional and formal tone in your responses.",
            "casual": "Use a friendly and casual tone, like talking to a good friend.",
            "technical": "Focus on technical accuracy and provide detailed explanations.",
            "educational": "Explain concepts clearly and use teaching techniques to help understanding.",
            "creative": "Be imaginative and inspiring in your responses, encouraging creativity.",
            "conversational": "Maintain a friendly, helpful, and engaging conversational tone."
        }
        
        base_prompt += f" {style_guidance.get(response_style, style_guidance['conversational'])}"
        
        # Add consistency reminder
        base_prompt += f"\n\nImportant: Always respond as {persona.name} and stay consistent with your described personality and expertise throughout the conversation."
        
        return base_prompt
    
    def _enhance_persona_response(self, response: str, persona) -> str:
        """Post-process response to ensure persona consistency"""
        if not persona or not response:
            return response
        
        # Remove any system prompts that might have leaked through
        if response.startswith(("You are", "I am", "As ")):
            lines = response.split('\n')
            # Find the first line that seems like actual response content
            for i, line in enumerate(lines):
                if line.strip() and not any(line.startswith(prefix) for prefix in ["You are", "I am", "As a", "My role"]):
                    response = '\n'.join(lines[i:])
                    break
        
        return response.strip()
    
    def get_persona_greeting(self, persona) -> str:
        """Generate a persona-specific greeting message"""
        if not persona:
            return "Hi! I'm Buddy, your AI assistant. How can I help you today?"
        
        greetings = {
            "teacher": f"Hello! I'm {persona.name}, ready to help you learn and understand new concepts step by step. What would you like to explore today?",
            "developer": f"Hey there! I'm {persona.name}, your coding companion. Whether you need help with programming, debugging, or technical solutions, I'm here to assist!",
            "writer": f"Greetings! I'm {persona.name}, here to help you craft compelling content, improve your writing, and express your ideas clearly. What can we create together?",
        }
        
        # Try to match persona name/description to get appropriate greeting
        name_lower = persona.name.lower()
        for key, greeting in greetings.items():
            if key in name_lower:
                return greeting
        
        # Default personalized greeting
        description_snippet = persona.description[:100] + "..." if persona.description and len(persona.description) > 100 else persona.description or ""
        return f"Hello! I'm {persona.name}. {description_snippet} How can I assist you today?"
    
    def _is_simple_greeting(self, prompt: str) -> bool:
        """Check if the prompt is a simple greeting - be more natural like ChatGPT"""
        prompt_lower = prompt.lower().strip()
        
        # Very simple patterns that clearly indicate basic social interaction
        simple_patterns = [
            'hi', 'hello', 'hey', 'hiya', 'yo',
            'good morning', 'good afternoon', 'good evening',
            'whats up', 'what\'s up', 'sup', 'howdy'
        ]
        
        # Only treat as simple if it's VERY clearly just a greeting
        # Let ChatGPT-like intelligence handle everything else naturally
        if len(prompt_lower) <= 15:  # Very short messages
            return any(greeting == prompt_lower or greeting in prompt_lower for greeting in simple_patterns)
        

        
        return False
    
    async def _generate_simple_response(self, prompt: str) -> Dict[str, Any]:
        """Generate natural, ChatGPT-like responses for simple interactions"""
        import random
        
        # Natural, conversational responses like ChatGPT
        simple_responses = [
            "Hi! I'm Buddy, your AI assistant. What can I help you with?",
            "Hello! How can I assist you today?",
            "Hey there! What would you like to work on?",
            "Hi! I'm here to help. What's on your mind?",
            "Hello! What can I help you accomplish today?",
            "Hey! Ready to help with whatever you need.",
            "Hi! What would you like to explore or work on?",
            "Hello! I'm here and ready to assist."
        ]
        
        response = random.choice(simple_responses)
        
        # Return simple, natural response - no complex JSON structure for greetings
        return {
            "type": "simple_response",
            "content": response,  # Just the text, no complex structure
            "ai_mode": "natural_conversation",
            "context_used": False
        }
    
    async def generate_flow_notes(self, 
                                 flow_data: Dict[str, Any], 
                                 user_context: Dict[str, Any],
                                 relevant_knowledge: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Generate notes for a flow when specifically requested
        Only called when user asks for notes to be added
        """
        try:
            generation_prompt = f"""
Generate contextual notes for this project flow:

FLOW TITLE: {flow_data.get('title', 'Project Flow')}
FLOW DESCRIPTION: {flow_data.get('description', 'No description')}

USER CONTEXT:
- Technical Stack: {user_context.get('technical_stack', [])}
- Experience Level: {user_context.get('usage_patterns', {})}

RELEVANT KNOWLEDGE:
{json.dumps(relevant_knowledge, indent=2) if relevant_knowledge else "No specific knowledge found"}

Generate useful notes in JSON format:
{{
    "technical_notes": [
        {{
            "title": "Technical consideration",
            "content": "Detailed technical note based on user's stack",
            "category": "architecture|implementation|testing|deployment",
            "references": ["knowledge base references"],
            "code_snippets": "if applicable"
        }}
    ],
    "contextual_insights": [
        {{
            "insight": "Personalized insight based on user patterns",
            "rationale": "Why this is relevant to this user",
            "action_items": ["specific actions"]
        }}
    ]
}}
"""
            
            response = await self.ai_client.generate_response(generation_prompt)
            
            # Parse response
            try:
                json_start = response.find('{')
                json_end = response.rfind('}') + 1
                if json_start != -1 and json_end != -1:
                    json_str = response[json_start:json_end]
                    return json.loads(json_str)
            except json.JSONDecodeError:
                pass
                
            # Fallback to simple notes
            return {
                "technical_notes": [
                    {
                        "title": "Project Notes",
                        "content": "Generated notes for your project flow",
                        "category": "general",
                        "references": [],
                        "code_snippets": ""
                    }
                ],
                "contextual_insights": []
            }
            
        except Exception as e:
            print(f"Error generating flow notes: {e}")
            return {"technical_notes": [], "contextual_insights": []}

    async def generate_flow_alarms(self, 
                                  flow_data: Dict[str, Any], 
                                  user_context: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Generate alarms/reminders for a flow when specifically requested
        Only called when user asks for alarms to be added
        """
        try:
            generation_prompt = f"""
Generate smart alarms/reminders for this project flow:

FLOW TITLE: {flow_data.get('title', 'Project Flow')}
ESTIMATED DURATION: {flow_data.get('estimated_duration', '2 weeks')}
COMPLEXITY: {flow_data.get('complexity_analysis', 'medium')}

USER PREFERENCES:
- Typical working hours: {user_context.get('working_hours', 'standard business hours')}
- Reminder preferences: {user_context.get('reminder_preferences', 'moderate')}

Generate practical alarms in JSON format:
[
    {{
        "title": "Smart reminder title",
        "description": "Context-aware reminder description",
        "type": "milestone|deadline|review|standup",
        "timing": "specific time recommendation",
        "priority": "high|medium|low",
        "auto_actions": ["actions to trigger"],
        "context": "why this alarm is needed"
    }}
]
"""
            
            response = await self.ai_client.generate_response(generation_prompt)
            
            # Parse response
            try:
                json_start = response.find('[')
                json_end = response.rfind(']') + 1
                if json_start != -1 and json_end != -1:
                    json_str = response[json_start:json_end]
                    return json.loads(json_str)
            except json.JSONDecodeError:
                pass
                
            # Fallback to basic alarms
            return [
                {
                    "title": f"Project Deadline: {flow_data.get('title', 'Project')}",
                    "description": "Reminder for project completion",
                    "type": "deadline",
                    "timing": flow_data.get('estimated_duration', '2 weeks'),
                    "priority": "high",
                    "auto_actions": ["notify"],
                    "context": "Project completion tracking"
                }
            ]
            
        except Exception as e:
            print(f"Error generating flow alarms: {e}")
            return []
