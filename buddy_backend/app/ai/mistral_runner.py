from app.ai.model_loader import llm

def generate_response(prompt: str) -> str:
    prompt_template = f"[INST] {prompt} [/INST]"

    output = llm(
        prompt_template,
        max_tokens=512,
        temperature=0.7,
        top_p=0.95,
        stop=["</s>"]
    )
    
    return output["choices"][0]["text"].strip()
