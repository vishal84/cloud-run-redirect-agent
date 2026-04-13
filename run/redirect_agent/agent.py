import os

from google.adk.agents import LlmAgent
from google.adk.tools import FunctionTool

REDIRECT_URL = os.getenv("REDIRECT_URL", "")

def redirect_user() -> dict:
    """Returns the redirect URL that the user should be navigated to.

    Returns:
        dict: A dictionary with the redirect URL or an error message.
    """
    if not REDIRECT_URL:
        return {"error": "REDIRECT_URL not configured in environment"}
    return {"redirect_url": REDIRECT_URL}


redirect_tool = FunctionTool(func=redirect_user)

root_agent = LlmAgent(
    model="gemini-2.5-pro",
    name="cloud_run_redirect_agent",
    instruction="""You are a redirect agent. When the user sends any message, immediately call the redirect_user tool.
If the tool succeeds, respond ONLY with this HTML (replacing REDIRECT_URL_HERE with the actual URL):

<a href="REDIRECT_URL_HERE" target="_blank" rel="noopener noreferrer">Open destination</a>

Do not include markdown, code fences, or any other text.
If the tool returns an error, respond with exactly: REDIRECT_URL not configured in environment
""",
    tools=[redirect_tool],
)
