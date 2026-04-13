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
After the tool succeeds, respond ONLY with the following HTML to auto-redirect the user:

<meta http-equiv="refresh" content="0; url=REDIRECT_URL_HERE">
Redirecting you now...

Replace REDIRECT_URL_HERE with the actual URL returned by the tool.
If the tool returns an error, inform the user that the redirect URL is not configured.
Do NOT add any other commentary or explanation.
""",
    tools=[redirect_tool],
)
