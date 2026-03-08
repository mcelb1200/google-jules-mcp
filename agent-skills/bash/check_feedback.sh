#!/bin/bash
# check_feedback.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

REPOSITORY=$1

echo "=== Checking Feedback ==="

RESPONSE=$(api_call "GET" "?pageSize=50" "")
TASKS=$(echo "$RESPONSE" | jq '[.sessions // [] | .[] | select(.state == "AWAITING_USER_FEEDBACK")]')

if [ "$TASKS" = "null" ] || [ $(echo "$TASKS" | jq length) -eq 0 ]; then
    echo "No sessions currently require user feedback."
    exit 0
fi

echo "The following tasks require your feedback:"

for row in $(echo "$TASKS" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }
    TASK_ID=$(_jq '.id // .name | split("/") | last')
    TITLE=$(_jq '.title')

    echo -e "\n--- Task $TASK_ID ($TITLE) ---"
    ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=10" "")
    LATEST_MESSAGE=$(echo "$ACTIVITIES" | jq -r '.activities[] | select(.agentMessaged) | .agentMessaged.prompt' | head -n 1)

    if [ "$LATEST_MESSAGE" != "null" ]; then
        echo -e "> $LATEST_MESSAGE"
    else
        echo "> Jules is awaiting feedback, but no message was found."
    fi
done
