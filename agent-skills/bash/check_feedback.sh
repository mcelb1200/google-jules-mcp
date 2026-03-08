#!/bin/bash
# check_feedback.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

echo -e "${YELLOW}=== Checking Feedback ===${NC}"

RESPONSE=$(api_call "GET" "?pageSize=50" "") || exit 1
TASKS=$(echo "$RESPONSE" | jq '[.sessions // [] | .[] | select(.state == "AWAITING_USER_FEEDBACK")]')

if [ "$TASKS" = "null" ] || [ $(echo "$TASKS" | jq length) -eq 0 ]; then
    echo "No sessions currently require user feedback."
    exit 0
fi

echo "The following tasks require your feedback:"

for row in $(echo "$TASKS" | jq -r '.[] | @base64'); do
    DECODED=$(echo ${row} | base64 --decode)
    TASK_ID=$(echo "$DECODED" | jq -r '.id // .name | split("/") | last')
    TITLE=$(echo "$DECODED" | jq -r '.title')

    echo -e "\n--- ${GREEN}Task $TASK_ID ($TITLE)${NC} ---"
    
    ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=50" "")
    if [ $? -eq 0 ]; then
        # Find the most recent agent message
        LATEST_MESSAGE=$(echo "$ACTIVITIES" | jq -r '.activities // [] | .[] | select(.agentMessaged) | .agentMessaged.agentMessage' | head -n 1)

        if [ "$LATEST_MESSAGE" != "null" ] && [ -n "$LATEST_MESSAGE" ]; then
            echo -e "${YELLOW}> $LATEST_MESSAGE${NC}"
        else
            echo -e "${RED}> Jules is awaiting feedback, but no message was found in recent activities.${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to retrieve activities for task $TASK_ID.${NC}"
    fi
done
