#!/usr/bin/env python3

print("🧪 TESTING UPDATED ROUTING LOGIC")
print("=" * 50)

def test_request_routing(prompt):
    prompt_lower = prompt.lower()
    
    # Code detection
    code_keywords = ['generate code', 'write code', 'create code', 'code for', 'build app', 'make program']
    is_simple_code_request = any(keyword in prompt_lower for keyword in code_keywords)
    
    # Greeting detection (updated logic)
    greeting_keywords = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening']
    is_simple_greeting = any(prompt.strip().lower() == keyword for keyword in greeting_keywords) or (
        any(keyword in prompt_lower for keyword in greeting_keywords) and len(prompt.split()) <= 2
    )
    
    bypass_thinking = is_simple_code_request or is_simple_greeting
    
    print(f"\nTesting: '{prompt}'")
    print(f"  Code request: {is_simple_code_request}")
    print(f"  Simple greeting: {is_simple_greeting}")
    print(f"  Bypass thinking: {bypass_thinking}")
    
    if bypass_thinking:
        print("  → ✅ Direct natural response (no AI Strategy)")
    else:
        print("  → 🧠 Use AI thinking service")

# Test cases
test_request_routing("generate code for calculator")
test_request_routing("hi")
test_request_routing("hello there")
test_request_routing("I need help with advanced machine learning algorithms for my research project")
test_request_routing("write code for a simple game")
test_request_routing("good morning")

print("\n" + "=" * 50)
print("🎯 Expected: Code requests and simple greetings bypass thinking")
print("   Complex requests use full AI analysis")
print("=" * 50)
