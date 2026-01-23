#!/bin/bash

# This script runs the Google Jules MCP Docker container.
# Usage: ./run_docker.sh [path_to_workspace]
# If no path is provided, the current directory is used.

# Resolve absolute path
WORKSPACE_PATH="${1:-$(pwd)}"
ABS_WORKSPACE_PATH=$(cd "$WORKSPACE_PATH" && pwd)

# Check if JULES_API_KEY is set; if not, try to load from .env in workspace
if [ -z "$JULES_API_KEY" ] && [ -f "$ABS_WORKSPACE_PATH/.env" ]; then
    # Extract key using grep/cut/sed to avoid sourcing the file directly (security)
    KEY=$(grep "^JULES_API_KEY=" "$ABS_WORKSPACE_PATH/.env" | cut -d '=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^["'\'']//;s/["'\'']$//')
    if [ -n "$KEY" ]; then
        export JULES_API_KEY="$KEY"
        echo "Loaded JULES_API_KEY from project .env file."
    fi
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: docker command not found." >&2
    exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running." >&2
    exit 1
fi

echo "Running Google Jules MCP for workspace: $ABS_WORKSPACE_PATH"

# Build environment variable arguments dynamically
ENV_ARGS=()
ENV_VARS=(
    "JULES_API_KEY"
    "SESSION_MODE"
    "BROWSERBASE_API_KEY"
    "BROWSERBASE_PROJECT_ID"
    "GOOGLE_AUTH_COOKIES"
)

for var in "${ENV_VARS[@]}"; do
    if [ -n "${!var}" ]; then
        ENV_ARGS+=("-e" "$var=${!var}")
    fi
done

# Run the container
# -i: Keep stdin open (required for MCP stdio transport)
# --rm: Remove container after exit
# -v: Mount workspace
docker run -i --rm \
  "${ENV_ARGS[@]}" \
  -v "$ABS_WORKSPACE_PATH:/projects" \
  -e CHROME_USER_DATA_DIR="/root/.jules-mcp/browser-data" \
  google-jules-mcp