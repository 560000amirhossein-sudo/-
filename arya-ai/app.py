import hmac
import os
from typing import Optional

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

APP_NAME = "ARYA AI"
API_ACCESS_TOKEN = os.getenv("API_ACCESS_TOKEN", "")
AI_API_KEY = os.getenv("AI_API_KEY", "")
AI_BASE_URL = os.getenv("AI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
AI_MODEL = os.getenv("AI_MODEL", "gpt-4o-mini")

app = FastAPI(title=APP_NAME, docs_url=None, redoc_url=None)

class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    conversation_id: Optional[str] = Field(default=None, max_length=100)

class ChatResponse(BaseModel):
    reply: str
    conversation_id: Optional[str] = None

def require_access(x_api_token: str = Header(default="")):
    if not API_ACCESS_TOKEN:
        raise HTTPException(status_code=503, detail="Server setup is incomplete.")
    if not hmac.compare_digest(x_api_token, API_ACCESS_TOKEN):
        raise HTTPException(status_code=401, detail="Unauthorized")

@app.get("/")
def root():
    return {"name": APP_NAME, "status": "running", "integration": "Shad connection not configured"}

@app.get("/health")
def health():
    return {"ok": True}

@app.post("/chat", response_model=ChatResponse, dependencies=[Depends(require_access)])
async def chat(body: ChatRequest):
    if not AI_API_KEY:
        raise HTTPException(status_code=503, detail="AI provider is not configured yet.")
    payload = {
        "model": AI_MODEL,
        "messages": [
            {"role": "system", "content": "تو ARYA AI هستی؛ دستیار فارسی‌زبان، دقیق، محترمانه و روشن. پاسخ‌ها را متناسب با سن دانش‌آموزان ایمن و آموزشی نگه دار. اگر مطمئن نیستی، صادقانه بگو."},
            {"role": "user", "content": body.message},
        ],
        "temperature": 0.6,
    }
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(f"{AI_BASE_URL}/chat/completions", headers={"Authorization": f"Bearer {AI_API_KEY}"}, json=payload)
            response.raise_for_status()
            data = response.json()
            reply = data["choices"][0]["message"]["content"]
            if not isinstance(reply, str) or not reply.strip():
                raise ValueError("Empty AI response")
            return ChatResponse(reply=reply.strip(), conversation_id=body.conversation_id)
    except httpx.HTTPStatusError as exc:
        raise HTTPException(status_code=502, detail="AI provider returned an error.") from exc
    except (httpx.HTTPError, KeyError, IndexError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Could not get an AI response.") from exc
