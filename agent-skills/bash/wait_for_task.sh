#!/bin/bash
# wait_for_task.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1
INTERVAL=${2:-15}
TIMEOUT=${3:-600}

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 [taskId] [pollIntervalSeconds] [timeoutSeconds]"
    exit 1
fi

echo "=== Waiting for Task $TASK_ID ==="
START_TIME=$(date +%s)

while true; do
    RESPONSE=$(api_call "GET" "/$TASK_ID" "")
    STATE=$(echo "$RESPONSE" | jq -r '.state')

    if [ "$STATE" = "null" ]; then
        echo "✗ Failed to retrieve task state."
        exit 1
    fi

    echo "Current State: $STATE"

    # Break if task hits a terminal or interactive state
    if [[ "$STATE" == "COMPLETED" || "$STATE" == "FAILED" || "$STATE" == "AWAITING_USER_FEEDBACK" || "$STATE" == "AWAITING_PLAN_APPROVAL" ]]; then
        echo -e "\n✓ Task has reached an interactive or terminal state: $STATE"

        if [ "$STATE" = "AWAITING_USER_FEEDBACK" ]; then
            ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=10" "")
            LATEST_MESSAGE=$(echo "$ACTIVITIES" | jq -r '.activities[] | select(.agentMessaged) | .agentMessaged.prompt' | head -n 1)
            if [ "$LATEST_MESSAGE" != "null" ]; then
                echo -e "JULES QUESTION:\n$LATEST_MESSAGE"
            fi
        fi
        exit 0
    fi

    # Check timeout
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "⚠ Timeout reached ($TIMEOUT seconds). Task is still in $STATE."
        exit 2
    fi

    # Wait
    sleep "$INTERVAL"
done
