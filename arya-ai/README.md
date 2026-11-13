# ARYA AI

An isolated Persian-language AI API service. This project lives in the arya-ai/ folder on the arya-ai branch and does not change the website's main branch.

## Deploy on Render

Create a new Web Service from this same GitHub repository with:
- Branch: arya-ai
- Root Directory: arya-ai
- Runtime: Python
- Build Command: pip install -r requirements.txt
- Start Command: uvicorn app:app --host 0.0.0.0 --port $PORT

Set these environment variables in Render (never commit secrets):
- API_ACCESS_TOKEN: a long random private token used by your own client
- AI_API_KEY: API key from an AI provider that supports the OpenAI Chat Completions format
- AI_BASE_URL: provider API base URL, default is https://api.openai.com/v1
- AI_MODEL: model name supported by that provider, default is gpt-4o-mini

## Endpoints
- GET /: service identity and status
- GET /health: health check
- POST /chat: protected AI chat endpoint; send JSON {"message":"سلام"} with header x-api-token

## Shad status
This is the AI backend only. A verified official/public Shad bot API has not been established, so this service does not log in to a personal Shad account, collect SMS codes, or automate the Shad app. Shad integration should be added only through a supported and authorized interface.
