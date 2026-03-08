#!/bin/bash
# common.sh

if [ -f .env.jclaw ]; then
    source .env.jclaw
fi

if [ -z "$JULES_API_KEY" ]; then
    echo "Error: JULES_API_KEY not found. Please run setup.sh first."
    exit 1
fi

API_BASE="https://jules.googleapis.com/v1alpha/sessions"

# Internal helper to handle API calls with status code checking
api_call() {
    local method=$1
    local endpoint=$2
    local body=$3
    local response_file=$(mktemp)
    local status_code

    if [ "$method" = "GET" ]; then
        status_code=$(curl -s -w "%{http_code}" -o "$response_file" -X GET "$API_BASE$endpoint" \
            -H "x-goog-api-key: $JULES_API_KEY" \
            -H "Content-Type: application/json")
    else
        status_code=$(curl -s -w "%{http_code}" -o "$response_file" -X "$method" "$API_BASE$endpoint" \
            -H "x-goog-api-key: $JULES_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$body")
    fi

    local response=$(cat "$response_file")
    rm "$response_file"

    if [[ "$status_code" -ne 200 ]]; then
        echo -e "\033[0;31mError: API call failed with status $status_code\033[0m" >&2
        echo "$response" | jq '.' >&2
        return 1
    fi

    echo "$response"
}

# Standardized ID extraction from a session object or ID string
extract_id() {
    local input=$1
    echo "$input" | jq -r '.id // .name // . | split("/") | last'
}

# Check if a command exists
check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
