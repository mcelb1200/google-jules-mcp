#!/bin/bash
# approve_plan.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 [taskId]"
    exit 1
fi

echo "=== Approving Plan ==="

BODY="{}"
RESPONSE=$(api_call "POST" "/$TASK_ID:approvePlan" "$BODY")

if echo "$RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "✗ Failed to approve plan. Response:"
    echo "$RESPONSE" | jq '.'
else
    echo "✓ Plan approved successfully for task $TASK_ID."
fi
