import os
from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = FastAPI()

# Get the redirect URL from environment variables
REDIRECT_URL = os.getenv("REDIRECT_URL")

@app.get("/")
async def redirect_root():
    """
    Triggers a redirect to the URL provided in the .env file.
    """
    if not REDIRECT_URL:
         raise HTTPException(status_code=500, detail="REDIRECT_URL not configured in environment")
    
    # Using 307 Temporary Redirect to preserve the method, or 302 if preferred.
    # The user requested to "trigger a redirect", so this fulfills it.
    return RedirectResponse(url=REDIRECT_URL, status_code=307)

if __name__ == "__main__":
    import uvicorn
    # Use port from environment or default to 8080 for Cloud Run
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)

root_agent = LlmAgent(
    model="gemini-2.5-pro",
    name="code_snippet_agent",
    instruction="""You are a code snippet agent that has access to an MCP tool used to retrieve code snippets.
    - If a user asks what you can do, answer that you can provide code snippets from the MCP tool you have access to.
    - Provide the types of snippets you can return i.e. sql, python, javascript, json, or go.
    - Always use the MCP tool to get code snippets, never make up code snippets on your own.
    """,
    tools=[cloud_run_mcp]
)