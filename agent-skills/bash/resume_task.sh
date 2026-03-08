#!/bin/bash
# resume_task.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 [taskId]"
    exit 1
fi

echo "=== Resuming Task ==="

MESSAGE_ESCAPED=$(echo "Please resume the task." | jq -Rs .)

BODY=$(cat <<EOF
{
  "prompt": $MESSAGE_ESCAPED
}
EOF
)

RESPONSE=$(api_call "POST" "/$TASK_ID:sendMessage" "$BODY")

if echo "$RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "✗ Failed to resume task. Response:"
    echo "$RESPONSE" | jq '.'
else
    echo "✓ Task $TASK_ID resumed successfully."
fi
