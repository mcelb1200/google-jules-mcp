#!/bin/bash
# send_message.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1
MESSAGE=$2

if [ -z "$TASK_ID" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 [taskId] [message]"
    exit 1
fi

echo "=== Sending Message ==="
MESSAGE_ESCAPED=$(echo "$MESSAGE" | jq -Rs .)

BODY=$(cat <<EOF
{
  "prompt": $MESSAGE_ESCAPED
}
EOF
)

RESPONSE=$(api_call "POST" "/$TASK_ID:sendMessage" "$BODY")

if echo "$RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "✗ Failed to send message. Response:"
    echo "$RESPONSE" | jq '.'
else
    echo "✓ Message sent successfully to task $TASK_ID."
fi
