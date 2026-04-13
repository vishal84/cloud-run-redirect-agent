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
