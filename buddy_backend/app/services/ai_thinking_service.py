"""
AI Thinking Service for backend
Provides advanced intent analysis and response strategy generation
"""
from typing import Dict, List, Any, Optional
import re
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class AIThinkingService:
    
    @staticmethod
    def analyze_intent(prompt: str) -> Dict[str, Any]:
        """Analyze user intent with advanced reasoning"""
        p = prompt.lower().strip()
        words = re.split(r'\s+', p)
        sentences = [s.strip() for s in re.split(r'[.!?]', p) if s.strip()]
        
        # Multi-layered intent analysis
        analysis = {
            'raw_prompt': prompt,
            'processed_text': p,
            'word_count': len(words),
            'sentence_count': len(sentences),
            'complexity_score': AIThinkingService._calculate_complexity(p, words, sentences),
        }

        # Intent classification with confidence scoring
        intents = {}
        
        # Primary intent categories with weighted scoring
        AIThinkingService._analyze_flow_creation_intent(p, words, intents)
        AIThinkingService._analyze_system_control_intent(p, words, intents)
        AIThinkingService._analyze_github_intent(p, words, intents)
        AIThinkingService._analyze_navigation_intent(p, words, intents)
        AIThinkingService._analyze_communication_intent(p, words, intents)
        AIThinkingService._analyze_task_management_intent(p, words, intents)
        AIThinkingService._analyze_information_retrieval_intent(p, words, intents)
        AIThinkingService._analyze_automation_intent(p, words, intents)
        
        # Multi-intent detection (user might want multiple things)
        multi_intents = [{'intent': k, 'confidence': v} for k, v in intents.items() if v > 0.5]
        
        # Primary intent is highest scoring
        primary_intent = max(intents.items(), key=lambda x: x[1]) if intents else ('unknown', 0.0)
        
        # Context and sentiment analysis
        context = AIThinkingService._analyze_context(p, words, sentences)
        sentiment = AIThinkingService._analyze_sentiment(p, words)
        urgency = AIThinkingService._analyze_urgency(p, words)
        
        # Reasoning chain
        reasoning = AIThinkingService._generate_reasoning_chain(p, intents, context, sentiment)
        
        analysis.update({
            'primary_intent': primary_intent[0],
            'primary_confidence': primary_intent[1],
            'all_intents': intents,
            'multi_intents': multi_intents,
            'context': context,
            'sentiment': sentiment,
            'urgency': urgency,
            'reasoning_chain': reasoning,
            'processing_strategy': AIThinkingService._determine_processing_strategy(primary_intent, context, urgency),
        })
        
        return analysis

    @staticmethod
    def generate_response_strategy(intent_analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Generate optimized response strategy based on analysis"""
        primary_intent = intent_analysis['primary_intent']
        confidence = intent_analysis['primary_confidence']
        context = intent_analysis['context']
        urgency = intent_analysis['urgency']
        
        strategy = {
            'response_type': AIThinkingService._determine_response_type(primary_intent, confidence),
            'execution_priority': AIThinkingService._calculate_execution_priority(urgency, confidence),
            'multi_step_required': intent_analysis['complexity_score'] > 7.0,
            'confirmation_needed': AIThinkingService._needs_confirmation(primary_intent, urgency),
            'estimated_duration': AIThinkingService._estimate_duration(primary_intent, context),
        }
        
        # Generate step-by-step execution plan
        strategy['execution_plan'] = AIThinkingService._generate_execution_plan(intent_analysis)
        
        # Determine if background processing is needed
        strategy['background_processing'] = AIThinkingService._needs_background_processing(primary_intent)
        
        # Risk assessment
        strategy['risk_assessment'] = AIThinkingService._assess_risks(primary_intent, context)
        
        return strategy

    @staticmethod
    def _calculate_complexity(text: str, words: List[str], sentences: List[str]) -> float:
        """Advanced complexity calculation"""
        complexity = 0.0
        
        # Length factors
        complexity += len(words) * 0.1
        complexity += len(sentences) * 0.5
        
        # Technical terms
        technical_terms = ['git', 'github', 'system', 'process', 'flow', 'api', 'database', 'server']
        complexity += len([w for w in words if w in technical_terms]) * 0.3
        
        # Conditional/complex structures
        complex_words = ['if', 'when', 'while', 'unless', 'however', 'although', 'because']
        complexity += len([w for w in words if w in complex_words]) * 0.5
        
        # Questions vs commands
        if '?' in text:
            complexity += 0.5
        if 'how' in words:
            complexity += 0.3
        if 'why' in words:
            complexity += 0.4
        
        return min(max(complexity, 0.0), 10.0)

    @staticmethod
    def _analyze_flow_creation_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze flow creation intent"""
        score = 0.0
        
        # Direct keywords
        flow_keywords = {'flow': 0.8, 'project': 0.6, 'plan': 0.5, 'workflow': 0.7, 'timeline': 0.6, 'schedule': 0.4}
        for word, weight in flow_keywords.items():
            if word in words:
                score += weight
        
        # Action words
        action_words = {'create', 'generate', 'build', 'make', 'design'}
        if any(w in words for w in action_words):
            score += 0.3
        
        # Context clues
        if 'notes and all' in text:
            score += 0.4
        if 'alarm' in text and 'reminder' in text:
            score += 0.3
        if 'meeting' in text:
            score += 0.2
        
        intents['flow_creation'] = min(score, 1.0)

    @staticmethod
    def _analyze_system_control_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze system control intent"""
        score = 0.0
        
        system_keywords = {'system': 0.8, 'process': 0.7, 'kill': 0.9, 'device': 0.6, 'dock': 0.8, 'monitor': 0.6}
        for word, weight in system_keywords.items():
            if word in words:
                score += weight
        
        # Command words
        command_words = {'run', 'execute', 'stop', 'start', 'control', 'manage'}
        if any(w in words for w in command_words):
            score += 0.4
        
        intents['system_control'] = min(score, 1.0)

    @staticmethod
    def _analyze_github_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze GitHub operations intent"""
        score = 0.0
        
        git_keywords = {'git': 0.9, 'github': 0.9, 'commit': 0.8, 'push': 0.8, 'pull': 0.8, 'clone': 0.8, 'repository': 0.7, 'repo': 0.7}
        for word, weight in git_keywords.items():
            if word in words:
                score += weight
        
        # GitHub-specific actions
        if 'github copilot' in text:
            score += 0.5
        if 'integrate' in text and 'github' in words:
            score += 0.4
        
        intents['github_operations'] = min(score, 1.0)

    @staticmethod
    def _analyze_navigation_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze navigation intent"""
        score = 0.0
        
        nav_keywords = {'navigate': 0.8, 'open': 0.6, 'show': 0.5, 'go': 0.4, 'display': 0.5, 'view': 0.4}
        for word, weight in nav_keywords.items():
            if word in words:
                score += weight
        
        # Screen/page references
        screens = {'screen', 'page', 'section', 'tab', 'menu'}
        if any(w in words for w in screens):
            score += 0.3
        
        intents['app_navigation'] = min(score, 1.0)

    @staticmethod
    def _analyze_communication_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze communication intent"""
        score = 0.0
        
        comm_keywords = {'message': 0.8, 'talk': 0.8, 'chat': 0.7, 'call': 0.8, 'meeting': 0.7, 'contact': 0.6}
        for word, weight in comm_keywords.items():
            if word in words:
                score += weight
        
        # Communication actions
        if 'on behalf of me' in text:
            score += 0.6
        if 'schedule meeting' in text:
            score += 0.5
        
        intents['communication'] = min(score, 1.0)

    @staticmethod
    def _analyze_task_management_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze task management intent"""
        score = 0.0
        
        task_keywords = {'note': 0.6, 'reminder': 0.7, 'alarm': 0.8, 'schedule': 0.6, 'task': 0.7, 'todo': 0.8}
        for word, weight in task_keywords.items():
            if word in words:
                score += weight
        
        intents['task_management'] = min(score, 1.0)

    @staticmethod
    def _analyze_information_retrieval_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze information retrieval intent"""
        score = 0.0
        
        info_keywords = {'what', 'how', 'why', 'when', 'where', 'show', 'tell', 'explain'}
        score += len([w for w in words if w in info_keywords]) * 0.3
        
        if '?' in text:
            score += 0.4
        
        intents['information_retrieval'] = min(score, 1.0)

    @staticmethod
    def _analyze_automation_intent(text: str, words: List[str], intents: Dict[str, float]) -> None:
        """Analyze automation intent"""
        score = 0.0
        
        auto_keywords = {'automatically': 0.8, 'auto': 0.7, 'automate': 0.9, 'macro': 0.8}
        for word, weight in auto_keywords.items():
            if word in text:  # Using 'in text' for partial matches like 'automatically'
                score += weight
        
        intents['automation'] = min(score, 1.0)

    @staticmethod
    def _analyze_context(text: str, words: List[str], sentences: List[str]) -> Dict[str, Any]:
        """Analyze context and environment"""
        return {
            'complexity': AIThinkingService._calculate_complexity(text, words, sentences),
            'technical_level': AIThinkingService._calculate_technical_level(words),
            'specificity': AIThinkingService._calculate_specificity(text, words),
            'completeness': AIThinkingService._calculate_completeness(text, sentences),
        }

    @staticmethod
    def _calculate_technical_level(words: List[str]) -> float:
        """Calculate technical level"""
        technical_terms = {
            'api', 'database', 'server', 'client', 'framework', 'library',
            'git', 'github', 'repository', 'commit', 'branch', 'merge',
            'system', 'process', 'thread', 'memory', 'cpu', 'kernel',
            'docker', 'kubernetes', 'microservice', 'endpoint', 'json', 'xml'
        }
        
        tech_count = len([w for w in words if w in technical_terms])
        return min((tech_count / len(words) * 10) if words else 0, 10.0)

    @staticmethod
    def _calculate_specificity(text: str, words: List[str]) -> float:
        """Calculate specificity"""
        specificity = 0.0
        
        # Specific names, numbers, paths
        if re.search(r'\b[A-Z][a-zA-Z]*\b', text):  # Proper nouns
            specificity += 2.0
        if re.search(r'\d+', text):  # Numbers
            specificity += 1.0
        if '/' in text or '\\' in text:  # Paths
            specificity += 1.5
        if '.' in text and not text.endswith('.'):  # File extensions
            specificity += 1.0
        
        return min(specificity, 10.0)

    @staticmethod
    def _calculate_completeness(text: str, sentences: List[str]) -> float:
        """Calculate completeness"""
        completeness = 5.0  # Start with medium completeness
        
        # Questions might indicate incomplete information
        if '?' in text:
            completeness -= 1.0
        if 'how' in text.lower():
            completeness -= 0.5
        
        # Specificity increases completeness
        if len(text) > 100:
            completeness += 1.0
        if len(sentences) > 2:
            completeness += 1.0
        
        return min(max(completeness, 0.0), 10.0)

    @staticmethod
    def _analyze_sentiment(text: str, words: List[str]) -> Dict[str, Any]:
        """Analyze sentiment and emotional context"""
        positive_words = {'please', 'thank', 'appreciate', 'help', 'great', 'awesome', 'perfect'}
        urgent_words = {'urgent', 'asap', 'quickly', 'immediately', 'fast', 'now', 'emergency'}
        polite_words = {'please', 'could', 'would', 'may', 'might', 'kindly'}
        
        positive = len([w for w in words if w in positive_words])
        urgent = len([w for w in words if w in urgent_words])
        polite = len([w for w in words if w in polite_words])
        
        return {
            'positivity': min((positive / len(words) * 10) if words else 0, 1.0),
            'urgency': min((urgent / len(words) * 20) if words else 0, 1.0),
            'politeness': min((polite / len(words) * 15) if words else 0, 1.0),
            'overall_tone': AIThinkingService._determine_overall_tone(positive, urgent, polite),
        }

    @staticmethod
    def _determine_overall_tone(positive: int, urgent: int, polite: int) -> str:
        """Determine overall tone"""
        if urgent > 0:
            return 'urgent'
        if polite > positive:
            return 'polite'
        if positive > 0:
            return 'positive'
        return 'neutral'

    @staticmethod
    def _analyze_urgency(text: str, words: List[str]) -> Dict[str, Any]:
        """Analyze urgency levels"""
        urgency_score = 0.0
        
        urgent_indicators = {
            'urgent': 0.9, 'asap': 0.9, 'immediately': 0.8, 'now': 0.6,
            'quickly': 0.5, 'fast': 0.4, 'soon': 0.3, 'emergency': 1.0
        }
        
        for word, weight in urgent_indicators.items():
            if word in words:
                urgency_score += weight
        
        # Punctuation can indicate urgency
        if '!' in text:
            urgency_score += 0.3
        if '!!' in text:
            urgency_score += 0.5
        
        urgency_score = min(urgency_score, 1.0)
        
        return {
            'score': urgency_score,
            'level': AIThinkingService._get_urgency_level(urgency_score),
            'requires_immediate_action': urgency_score > 0.7,
        }

    @staticmethod
    def _get_urgency_level(score: float) -> str:
        """Get urgency level from score"""
        if score >= 0.8:
            return 'critical'
        elif score >= 0.6:
            return 'high'
        elif score >= 0.4:
            return 'medium'
        elif score >= 0.2:
            return 'low'
        return 'none'

    @staticmethod
    def _generate_reasoning_chain(
        prompt: str,
        intents: Dict[str, float],
        context: Dict[str, Any],
        sentiment: Dict[str, Any],
    ) -> List[str]:
        """Generate human-like reasoning chain"""
        reasoning = []
        
        # Step 1: Understanding
        reasoning.append(f'🧠 Analyzing user request: "{prompt[:50] + "..." if len(prompt) > 50 else prompt}"')
        
        # Step 2: Intent recognition
        top_intents = sorted(intents.items(), key=lambda x: x[1], reverse=True)
        top_intents = [(k, v) for k, v in top_intents if v > 0.3]
        
        if top_intents:
            reasoning.append(f'🎯 Detected intent: {top_intents[0][0]} ({int(top_intents[0][1] * 100)}% confidence)')
            
            if len(top_intents) > 1:
                secondary = ', '.join([f'{k} ({int(v * 100)}%)' for k, v in top_intents[1:3]])
                reasoning.append(f'🔄 Secondary intents: {secondary}')
        
        # Step 3: Context analysis
        if context['complexity'] > 5:
            reasoning.append('⚙️ Complex request detected - breaking down into manageable steps')
        
        # Step 4: Sentiment consideration
        if sentiment['urgency'] > 0.7:
            reasoning.append('⚡ High urgency detected - prioritizing immediate action')
        elif sentiment['politeness'] > 0.8:
            reasoning.append('😊 Polite request - ensuring thorough and helpful response')
        
        # Step 5: Action planning
        reasoning.append('📋 Planning optimal execution strategy...')
        
        return reasoning

    # Additional helper methods for response strategy
    @staticmethod
    def _determine_processing_strategy(
        primary_intent: tuple,
        context: Dict[str, Any],
        urgency: Dict[str, Any],
    ) -> str:
        """Determine processing strategy"""
        if urgency['score'] > 0.7:
            return 'immediate_execution'
        if context['complexity'] > 7.0:
            return 'step_by_step_processing'
        if primary_intent[1] < 0.6:
            return 'clarification_needed'
        if context['technical_level'] > 7.0:
            return 'expert_mode'
        
        return 'standard_processing'

    @staticmethod
    def _determine_response_type(intent: str, confidence: float) -> str:
        """Determine response type"""
        if confidence < 0.5:
            return 'clarification_request'
        if intent == 'system_control':
            return 'action_with_confirmation'
        if intent == 'github_operations':
            return 'technical_execution'
        if intent == 'flow_creation':
            return 'creative_generation'
        
        return 'standard_response'

    @staticmethod
    def _calculate_execution_priority(urgency: Dict[str, Any], confidence: float) -> int:
        """Calculate execution priority"""
        priority = 5  # Medium priority
        
        urgency_score = urgency['score']
        if urgency_score > 0.8:
            priority = 1  # Critical
        elif urgency_score > 0.6:
            priority = 2  # High
        elif urgency_score > 0.4:
            priority = 3  # Medium-high
        
        # Adjust based on confidence
        if confidence < 0.5:
            priority += 2  # Lower priority if uncertain
        
        return min(max(priority, 1), 10)

    @staticmethod
    def _needs_confirmation(intent: str, urgency: Dict[str, Any]) -> bool:
        """Check if confirmation is needed"""
        high_risk_intents = {'system_control', 'github_operations'}
        return intent in high_risk_intents and urgency['score'] < 0.8

    @staticmethod
    def _estimate_duration(intent: str, context: Dict[str, Any]) -> str:
        """Estimate duration"""
        durations = {
            'system_control': 'immediate',
            'github_operations': '30-60 seconds',
            'flow_creation': '1-2 minutes',
            'app_navigation': 'immediate',
        }
        
        if intent in durations:
            return durations[intent]
        
        return '30-60 seconds' if context['complexity'] > 5 else 'immediate'

    @staticmethod
    def _generate_execution_plan(analysis: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate execution plan"""
        intent = analysis['primary_intent']
        multi_intents = analysis['multi_intents']
        
        plan = []
        
        # Primary action
        plan.append({
            'step': 1,
            'action': intent,
            'description': AIThinkingService._get_intent_description(intent),
            'estimated_duration': AIThinkingService._estimate_duration(intent, analysis['context']),
        })
        
        # Secondary actions for multi-intent scenarios
        for i, secondary in enumerate(multi_intents[:2]):
            if secondary['intent'] != intent:
                plan.append({
                    'step': len(plan) + 1,
                    'action': secondary['intent'],
                    'description': AIThinkingService._get_intent_description(secondary['intent']),
                    'estimated_duration': AIThinkingService._estimate_duration(secondary['intent'], analysis['context']),
                })
        
        return plan

    @staticmethod
    def _get_intent_description(intent: str) -> str:
        """Get description for intent"""
        descriptions = {
            'flow_creation': 'Create comprehensive project flow with notes, alarms, and meetings',
            'system_control': 'Execute system operations and process management',
            'github_operations': 'Perform Git/GitHub operations',
            'app_navigation': 'Navigate to specific app sections',
            'communication': 'Handle messaging and communication tasks',
            'task_management': 'Manage notes, reminders, and tasks',
        }
        return descriptions.get(intent, 'Process user request')

    @staticmethod
    def _needs_background_processing(intent: str) -> bool:
        """Check if background processing is needed"""
        background_intents = {'github_operations', 'system_control', 'flow_creation'}
        return intent in background_intents

    @staticmethod
    def _assess_risks(intent: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """Assess risks"""
        risks = {
            'level': 'low',
            'factors': [],
        }
        
        if intent == 'system_control':
            risks['level'] = 'high'
            risks['factors'].append('System modification capabilities')
        
        if intent == 'github_operations' and context['technical_level'] > 7:
            risks['level'] = 'medium'
            risks['factors'].append('Git repository modifications')
        
        return risks
