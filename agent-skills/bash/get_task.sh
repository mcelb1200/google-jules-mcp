#!/bin/bash
# get_task.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 [taskId]"
    exit 1
fi

echo "=== Getting Task Details ==="

RESPONSE=$(api_call "GET" "/$TASK_ID" "")
STATE=$(echo "$RESPONSE" | jq -r '.state')

if [ "$STATE" = "null" ]; then
    echo "✗ Failed to retrieve task or task not found."
    echo "$RESPONSE" | jq '.'
    exit 1
fi

echo "Task ID: $TASK_ID"
echo "Title: $(echo "$RESPONSE" | jq -r '.title')"
echo "State: $STATE"

if [ "$STATE" = "AWAITING_USER_FEEDBACK" ]; then
    echo "⚠ Task is awaiting user feedback."
    echo "Fetching latest agent message..."
    ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=10" "")
    LATEST_MESSAGE=$(echo "$ACTIVITIES" | jq -r '.activities[] | select(.agentMessaged) | .agentMessaged.prompt' | head -n 1)
    if [ "$LATEST_MESSAGE" != "null" ]; then
        echo -e "\nJULES QUESTION:\n$LATEST_MESSAGE"
    else
        echo "Failed to retrieve the latest message from Jules."
    fi
fi
