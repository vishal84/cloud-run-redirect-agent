#!/usr/bin/env bash
set -euo pipefail

# Registers a Cloud Run A2A agent with Gemini Enterprise (Discovery Engine).
# Required env vars:
#   PROJECT_ID         e.g. gemini-ent-agent-demos
#   APP_ID             Gemini Enterprise app ID (engine ID)
#   LOCATION           App location: global|us|eu
#   AGENT_CARD_URL     Full URL to your A2A agent card JSON
# Optional env vars:
#   ENDPOINT_LOCATION  API endpoint location: global|us|eu (default: LOCATION)
#   AGENT_DISPLAY_NAME Display name shown in Agent Gallery
#   AGENT_DESCRIPTION  Description shown in Agent Gallery

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

require_cmd gcloud
require_cmd curl
require_cmd jq

require_var PROJECT_ID
require_var APP_ID
require_var LOCATION
require_var AGENT_CARD_URL

ENDPOINT_LOCATION="${ENDPOINT_LOCATION:-$LOCATION}"

if [[ "$ENDPOINT_LOCATION" != "global" && "$ENDPOINT_LOCATION" != "us" && "$ENDPOINT_LOCATION" != "eu" ]]; then
  echo "ENDPOINT_LOCATION must be one of: global, us, eu" >&2
  exit 1
fi

if [[ "$LOCATION" != "global" && "$LOCATION" != "us" && "$LOCATION" != "eu" ]]; then
  echo "LOCATION must be one of: global, us, eu" >&2
  exit 1
fi

echo "Fetching agent card from: $AGENT_CARD_URL"
agent_card_json="$(curl --fail-with-body -sS "$AGENT_CARD_URL")"

# Validate JSON and extract defaults.
echo "$agent_card_json" | jq . >/dev/null

default_name="$(echo "$agent_card_json" | jq -r '.name // "Cloud Run A2A Agent"')"
default_desc="$(echo "$agent_card_json" | jq -r '.description // "A2A agent registered from Cloud Run"')"

AGENT_DISPLAY_NAME="${AGENT_DISPLAY_NAME:-$default_name}"
AGENT_DESCRIPTION="${AGENT_DESCRIPTION:-$default_desc}"

access_token="$(gcloud auth print-access-token)"
base_url="https://${ENDPOINT_LOCATION}-discoveryengine.googleapis.com/v1alpha"
parent="projects/${PROJECT_ID}/locations/${LOCATION}/collections/default_collection/engines/${APP_ID}/assistants/default_assistant"
create_url="${base_url}/${parent}/agents"
list_url="${base_url}/${parent}/agents"

request_body="$(jq -n \
  --arg displayName "$AGENT_DISPLAY_NAME" \
  --arg description "$AGENT_DESCRIPTION" \
  --argjson agentCard "$agent_card_json" \
  '{
    displayName: $displayName,
    description: $description,
    a2aAgentDefinition: {
      jsonAgentCard: ($agentCard | tojson)
    }
  }'
)"

echo "Registering A2A agent in app: $APP_ID"
create_response="$(curl --fail-with-body -sS -X POST "$create_url" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json" \
  -d "$request_body"
)"

echo "Create response:"
echo "$create_response" | jq .

echo
echo "Listing agents connected to this app:"
curl --fail-with-body -sS -X GET "$list_url" \
  -H "Authorization: Bearer $access_token" | jq .
