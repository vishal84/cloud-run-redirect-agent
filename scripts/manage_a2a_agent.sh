#!/usr/bin/env bash
set -euo pipefail

# Manage a Gemini Enterprise A2A agent registration.
#
# Usage:
#   ./scripts/manage_a2a_agent.sh list
#   ./scripts/manage_a2a_agent.sh get <AGENT_ID>
#   ./scripts/manage_a2a_agent.sh update <AGENT_ID>
#   ./scripts/manage_a2a_agent.sh delete <AGENT_ID>
#
# Required env vars:
#   PROJECT_ID         e.g. gemini-ent-agent-demos
#   APP_ID             Gemini Enterprise app ID (engine ID)
#   LOCATION           App location: global|us|eu
#   ENDPOINT_LOCATION  API endpoint location: global|us|eu (default: LOCATION)
#
# Additional env vars for update:
#   AGENT_CARD_URL     Full URL to your A2A agent card JSON
#   AGENT_DISPLAY_NAME Optional display name override
#   AGENT_DESCRIPTION  Optional description override

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

validate_location() {
  local value="$1"
  local label="$2"
  if [[ "$value" != "global" && "$value" != "us" && "$value" != "eu" ]]; then
    echo "$label must be one of: global, us, eu" >&2
    exit 1
  fi
}

require_cmd gcloud
require_cmd curl
require_cmd jq

require_var PROJECT_ID
require_var APP_ID
require_var LOCATION

ENDPOINT_LOCATION="${ENDPOINT_LOCATION:-$LOCATION}"
validate_location "$LOCATION" "LOCATION"
validate_location "$ENDPOINT_LOCATION" "ENDPOINT_LOCATION"

access_token="$(gcloud auth print-access-token)"
base_url="https://${ENDPOINT_LOCATION}-discoveryengine.googleapis.com/v1alpha"
parent="projects/${PROJECT_ID}/locations/${LOCATION}/collections/default_collection/engines/${APP_ID}/assistants/default_assistant"
agents_url="${base_url}/${parent}/agents"

cmd="${1:-}"
if [[ -z "$cmd" ]]; then
  echo "Missing command. Use: list | get <AGENT_ID> | update <AGENT_ID> | delete <AGENT_ID>" >&2
  exit 1
fi

case "$cmd" in
  list)
    curl --fail-with-body -sS -X GET "$agents_url" \
      -H "Authorization: Bearer $access_token" | jq .
    ;;

  get)
    agent_id="${2:-}"
    if [[ -z "$agent_id" ]]; then
      echo "Missing AGENT_ID. Usage: $0 get <AGENT_ID>" >&2
      exit 1
    fi
    curl --fail-with-body -sS -X GET "${agents_url}/${agent_id}" \
      -H "Authorization: Bearer $access_token" | jq .
    ;;

  update)
    agent_id="${2:-}"
    if [[ -z "$agent_id" ]]; then
      echo "Missing AGENT_ID. Usage: $0 update <AGENT_ID>" >&2
      exit 1
    fi

    require_var AGENT_CARD_URL

    agent_card_json="$(curl --fail-with-body -sS "$AGENT_CARD_URL")"
    echo "$agent_card_json" | jq . >/dev/null

    default_name="$(echo "$agent_card_json" | jq -r '.name // "Cloud Run A2A Agent"')"
    default_desc="$(echo "$agent_card_json" | jq -r '.description // "A2A agent registered from Cloud Run"')"

    display_name="${AGENT_DISPLAY_NAME:-$default_name}"
    description="${AGENT_DESCRIPTION:-$default_desc}"

    request_body="$(jq -n \
      --arg displayName "$display_name" \
      --arg description "$description" \
      --argjson agentCard "$agent_card_json" \
      '{
        displayName: $displayName,
        description: $description,
        a2aAgentDefinition: {
          jsonAgentCard: ($agentCard | tojson)
        }
      }'
    )"

    curl --fail-with-body -sS -X PATCH "${agents_url}/${agent_id}?updateMask=displayName,description,a2aAgentDefinition" \
      -H "Authorization: Bearer $access_token" \
      -H "Content-Type: application/json" \
      -d "$request_body" | jq .
    ;;

  delete)
    agent_id="${2:-}"
    if [[ -z "$agent_id" ]]; then
      echo "Missing AGENT_ID. Usage: $0 delete <AGENT_ID>" >&2
      exit 1
    fi

    curl --fail-with-body -sS -X DELETE "${agents_url}/${agent_id}" \
      -H "Authorization: Bearer $access_token" | jq .
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    echo "Use: list | get <AGENT_ID> | update <AGENT_ID> | delete <AGENT_ID>" >&2
    exit 1
    ;;
esac
