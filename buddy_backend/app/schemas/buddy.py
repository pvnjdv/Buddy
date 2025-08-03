from pydantic import BaseModel

class PromptRequest(BaseModel):
    text: str

class PromptResponse(BaseModel):
    response: str
