
from llama_cpp import Llama
import os

class LlamaModelWrapper:
    def __init__(self, model_path: str):
        self.llm = Llama(
            model_path=model_path,
            n_ctx=1024,
            n_threads=8,
            n_gpu_layers=15,
            verbose=True
        )

    def generate_response(self, prompt: str) -> str:
        prompt_template = f"[INST] {prompt} [/INST]"
        output = self.llm(
            prompt_template,
            max_tokens=64,
            temperature=0.7,
            top_p=0.95,
            stop=["</s>"]
        )
        return output["choices"][0]["text"].strip()

def load_ai_model(model_name: str, model_path: str):
    print(f"Loading model: {model_name} from {model_path}")
    return LlamaModelWrapper(model_path)