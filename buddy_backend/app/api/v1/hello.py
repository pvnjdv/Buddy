from fastapi import APIRouter

router = APIRouter()

@router.get("/hello")
def say_hello():
    return {"message": "Hey from /api/v1/hello 👋"}
