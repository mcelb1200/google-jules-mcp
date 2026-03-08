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

api_call() {
    local method=$1
    local endpoint=$2
    local body=$3

    if [ "$method" = "GET" ]; then
        curl -s -X GET "$API_BASE$endpoint" \
            -H "x-goog-api-key: $JULES_API_KEY" \
            -H "Content-Type: application/json"
    else
        curl -s -X "$method" "$API_BASE$endpoint" \
            -H "x-goog-api-key: $JULES_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$body"
    fi
}
