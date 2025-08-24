#!/usr/bin/env python3

# Simple test to understand what's happening when we ask for code generation
# This isolates the issue without running the full backend

def test_code_detection():
    prompt = "generate code for calculator"
    
    # Test the keyword detection logic that should be working
    code_keywords = ['generate code', 'write code', 'create code', 'code for', 'build app', 'make program']
    prompt_lower = prompt.lower()
    
    print(f"Testing prompt: '{prompt}'")
    print(f"Prompt lower: '{prompt_lower}'")
    
    for keyword in code_keywords:
        if keyword in prompt_lower:
            print(f"✅ MATCH: '{keyword}' found in prompt")
        else:
            print(f"❌ NO MATCH: '{keyword}' not found")
    
    is_code_request = any(keyword in prompt_lower for keyword in code_keywords)
    print(f"\nFinal result: is_code_request = {is_code_request}")
    
    if is_code_request:
        print("✅ SUCCESS: Should route to code generation")
    else:
        print("❌ FAILURE: Will not route to code generation")

if __name__ == "__main__":
    test_code_detection()
