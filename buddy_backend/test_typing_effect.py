#!/usr/bin/env python3

print("🎬 TESTING WORD-BY-WORD TYPING EFFECT")
print("=" * 50)

# Simulate the typing effect timing
import time

test_response = "Here's your calculator code: def add(a, b): return a + b. This function takes two parameters and returns their sum."

words = test_response.split()
typing_speed = 0.08  # 80ms in seconds

print("Testing response:", test_response)
print(f"Word count: {len(words)}")
print(f"Estimated typing time: {len(words) * typing_speed:.1f} seconds")
print("\nSimulating word-by-word display:")
print("-" * 30)

displayed_text = ""
for i, word in enumerate(words):
    if i == 0:
        displayed_text = word
    else:
        displayed_text += f" {word}"
    
    print(f"\r{displayed_text}", end="", flush=True)
    time.sleep(typing_speed)

print("\n" + "-" * 30)
print("✅ Typing effect simulation complete!")
print("🎯 This creates a natural ChatGPT-like word-by-word response!")
