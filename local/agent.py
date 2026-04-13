import os
import webbrowser

from dotenv import load_dotenv
from google.adk.agents import LlmAgent
from google.adk.tools import FunctionTool

load_dotenv()

REDIRECT_URL = os.getenv("REDIRECT_URL", "")


def redirect_user() -> dict:
    """Redirects the user by opening the configured URL in their browser.

    Returns:
        dict: A dictionary with the result of the redirect attempt.
    """
    if not REDIRECT_URL:
        return {"error": "REDIRECT_URL not configured in environment"}
    webbrowser.open(REDIRECT_URL)
    return {"status": "success", "message": f"Redirected to {REDIRECT_URL}"}


redirect_tool = FunctionTool(func=redirect_user)

root_agent = LlmAgent(
    model="gemini-2.5-pro",
    name="cloud_run_redirect_agent",
    instruction="""You are a redirect agent. When the user sends any message, immediately call the redirect_user tool.
After the tool succeeds, respond with a brief confirmation that the user has been redirected.
If the tool returns an error, inform the user that the redirect URL is not configured.
Do NOT add any other commentary or explanation.
""",
    tools=[redirect_tool],
)