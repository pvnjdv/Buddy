#!/usr/bin/env python3

print("🧪 TESTING NATURAL CODE GENERATION")
print("=" * 50)

# Test 1: Keyword Detection
print("\n1. Testing Keyword Detection:")
prompt = "generate code for calculator"
code_keywords = ['generate code', 'write code', 'create code', 'code for', 'build app', 'make program']
is_simple_code_request = any(keyword in prompt.lower() for keyword in code_keywords)
print(f"   Prompt: '{prompt}'")
print(f"   Detected as code request: {is_simple_code_request}")
if is_simple_code_request:
    print("   ✅ PASS: Will bypass AI thinking service")
else:
    print("   ❌ FAIL: Will go through AI thinking service")

# Test 2: Greeting Detection
print("\n2. Testing Greeting Detection:")
greeting = "hi"
greeting_keywords = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening']
is_simple_greeting = any(keyword in greeting.lower() for keyword in greeting_keywords) and len(greeting.split()) <= 3
print(f"   Prompt: '{greeting}'")
print(f"   Detected as simple greeting: {is_simple_greeting}")
if is_simple_greeting:
    print("   ✅ PASS: Will bypass AI thinking service")
else:
    print("   ❌ FAIL: Will go through AI thinking service")

# Test 3: Complex Request
print("\n3. Testing Complex Request:")
complex_prompt = "I need help with advanced machine learning algorithms for my research project"
is_complex = not (any(keyword in complex_prompt.lower() for keyword in code_keywords) or 
                 any(keyword in complex_prompt.lower() for keyword in greeting_keywords))
print(f"   Prompt: '{complex_prompt}'")
print(f"   Should use thinking service: {is_complex}")
if is_complex:
    print("   ✅ PASS: Will use AI thinking service for comprehensive analysis")
else:
    print("   ❌ FAIL: Will bypass thinking service (wrong for complex requests)")

print("\n" + "=" * 50)
print("🎯 EXPECTED BEHAVIOR:")
print("✅ 'generate code for calculator' → Direct code generation (no AI Strategy)")
print("✅ 'hi' → Direct natural greeting (no AI Strategy)")
print("✅ Complex questions → Full AI analysis with thinking")
print("=" * 50)
