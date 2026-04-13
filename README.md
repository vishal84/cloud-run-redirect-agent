# Cloud Run Redirect Agent

An A2A (Agent-to-Agent) agent hosted on Google Cloud Run that redirects users to a configured URL. Built with the [Google ADK](https://google.github.io/adk-docs/) and compatible with Gemini Enterprise Agent Gallery.

## Project Structure

```
├── local/                  # Local development agent (uses webbrowser.open)
│   ├── __init__.py
│   └── agent.py
├── run/                    # Cloud Run deployment
│   ├── Dockerfile
│   ├── main.py             # FastAPI entry point with A2A support
│   ├── requirements.txt
│   └── redirect_agent/
│       ├── agent.py         # LLM agent with redirect tool
│       └── agent.json       # A2A agent card
├── scripts/
│   ├── register_a2a_agent.sh   # Register agent with Gemini Enterprise
│   └── manage_a2a_agent.sh     # List/get/update/delete registrations
├── pyproject.toml
├── example.env             # Template — copy to .env and fill in your values
└── .env                    # Your environment variables (git-ignored)
```

## Prerequisites

- Python 3.14+
- [uv](https://docs.astral.sh/uv/) package manager
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`)
- A Google Cloud project with Vertex AI enabled
- `jq` and `curl` (for registration scripts)

---

## 1. Local Development

### Install dependencies

```bash
uv sync
```

This creates a `.venv` virtual environment and installs all dependencies from `pyproject.toml`.

### Set environment variables

Copy the included `example.env` to `.env` and fill in your values:

```bash
cp example.env .env
```

At minimum, set `REDIRECT_URL` and `GOOGLE_CLOUD_PROJECT` for local development. See the `.env` file for all available variables.

### Run locally with ADK Web

```bash
source .venv/bin/activate
adk web local
```

This launches the ADK web UI pointed at the `local/` agent directory. The local agent uses `webbrowser.open()` to open the redirect URL in your browser.

### Run Cloud Run agent locally

To test the Cloud Run version (A2A mode) locally:

```bash
source .venv/bin/activate
cd run
REDIRECT_URL=https://www.example.com \
GOOGLE_CLOUD_PROJECT=your-gcp-project-id \
GOOGLE_CLOUD_LOCATION=us-central1 \
GOOGLE_GENAI_USE_VERTEXAI=True \
python main.py
```

Verify the agent card is served:

```bash
curl http://localhost:8080/a2a/redirect_agent/.well-known/agent-card.json
```

Test a message:

```bash
curl -X POST http://localhost:8080/a2a/redirect_agent \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "message/send",
    "params": {
      "message": {
        "messageId": "msg-001",
        "role": "user",
        "parts": [{"kind": "text", "text": "redirect me"}]
      }
    }
  }'
```

---

## 2. Deploy to Cloud Run

### Authenticate with Google Cloud

```bash
gcloud auth login
gcloud config set project your-gcp-project-id
```

### Deploy

```bash
gcloud run deploy cloud-run-redirect-agent \
  --source run \
  --project your-gcp-project-id \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars REDIRECT_URL=https://www.example.com,GOOGLE_CLOUD_PROJECT=your-gcp-project-id,GOOGLE_CLOUD_LOCATION=us-central1,GOOGLE_GENAI_USE_VERTEXAI=True
```

| Environment Variable | Description |
|---|---|
| `REDIRECT_URL` | The URL users will be redirected to |
| `GOOGLE_CLOUD_PROJECT` | Your GCP project ID |
| `GOOGLE_CLOUD_LOCATION` | Vertex AI region (e.g. `us-central1`) |
| `GOOGLE_GENAI_USE_VERTEXAI` | Must be `True` to use Vertex AI |

### Verify the deployment

After deploying, note the service URL from the output, then verify:

```bash
# Check agent card
curl https://YOUR_SERVICE_URL/a2a/redirect_agent/.well-known/agent-card.json

# Test redirect
curl -X POST https://YOUR_SERVICE_URL/a2a/redirect_agent \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "message/send",
    "params": {
      "message": {
        "messageId": "msg-001",
        "role": "user",
        "parts": [{"kind": "text", "text": "redirect me"}]
      }
    }
  }'
```

### Update the agent card URL

After your first deployment, update `run/redirect_agent/agent.json` to set the `url` field to your actual Cloud Run service URL:

```json
{
  "url": "https://YOUR_SERVICE_URL/a2a/redirect_agent"
}
```

Then redeploy.

---

## 3. Register with Gemini Enterprise

The registration scripts use the Discovery Engine API to add your A2A agent to the Gemini Enterprise Agent Gallery.

### Set up `.env`

If you haven't already, copy `example.env` to `.env` and fill in the registration-specific values:

```bash
cp example.env .env
```

The registration scripts require these variables to be set in `.env`:

| Variable | Required | Description |
|---|---|---|
| `PROJECT_ID` | Yes | GCP project ID |
| `APP_ID` | Yes | Gemini Enterprise engine ID |
| `LOCATION` | Yes | App location: `global`, `us`, or `eu` |
| `ENDPOINT_LOCATION` | No | API endpoint location (defaults to `LOCATION`) |
| `AGENT_CARD_URL` | Yes | Full URL to your deployed agent card JSON |
| `AGENT_DISPLAY_NAME` | No | Display name in Agent Gallery (defaults to agent card `name`) |
| `AGENT_DESCRIPTION` | No | Description in Agent Gallery (defaults to agent card `description`) |

### Register the agent

```bash
chmod +x scripts/register_a2a_agent.sh
./scripts/register_a2a_agent.sh
```

The script will:

1. Source the `.env` file automatically
2. Fetch and validate the agent card from `AGENT_CARD_URL`
3. Register the agent with the Discovery Engine API
4. Print the created agent resource and list all registered agents

### Manage registered agents

```bash
chmod +x scripts/manage_a2a_agent.sh

# List all agents
./scripts/manage_a2a_agent.sh list

# Get a specific agent
./scripts/manage_a2a_agent.sh get AGENT_ID

# Update an agent (re-fetches agent card from AGENT_CARD_URL)
./scripts/manage_a2a_agent.sh update AGENT_ID

# Delete an agent
./scripts/manage_a2a_agent.sh delete AGENT_ID
```

The `AGENT_ID` is returned in the registration response (the last segment of the `name` field).

You can also pass variables inline instead of using `.env`:

```bash
PROJECT_ID=my-project APP_ID=my-engine LOCATION=global ./scripts/manage_a2a_agent.sh list
```
