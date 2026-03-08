#!/bin/bash
# audit_report.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 [taskId]"
    exit 1
fi

echo "=== Generating Audit Report ==="

RESPONSE=$(api_call "GET" "/$TASK_ID" "")
if echo "$RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "✗ Failed to fetch session. Response:"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

TITLE=$(echo "$RESPONSE" | jq -r '.title')
STATE=$(echo "$RESPONSE" | jq -r '.state')
SOURCE=$(echo "$RESPONSE" | jq -r '.sourceContext.source // "Unknown"')
PROMPT=$(echo "$RESPONSE" | jq -r '.prompt // "No initial prompt record available."')

ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=50" "")
EVENTS=$(echo "$ACTIVITIES" | jq -r '.activities // []')

# Process Activities for Audit
echo -e "# 🛡️ Jules Session Audit Report\n"
echo -e "**Session ID**: \`$TASK_ID\`"
echo -e "**Title**: $TITLE"
echo -e "**Final State**: \`$STATE\`"
echo -e "**Repository**: $SOURCE"
echo -e "**Generated At**: $(date)\n"

echo -e "## 📝 Intent Statement (Initial Prompt)\n> $PROMPT\n"

echo -e "## 🔄 Delivery Activity Log\n| Timestamp | Event Type | Details |\n| :--- | :--- | :--- |"

for row in $(echo "$EVENTS" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }
    CREATE_TIME=$(_jq '.createTime')
    if [ $(_jq 'has("planGenerated")') == "true" ]; then
        EVENT_TYPE="PLAN_GENERATED"
        DETAIL="Plan contains $(_jq '.planGenerated.steps | length') steps."
    elif [ $(_jq 'has("planApproved")') == "true" ]; then
        EVENT_TYPE="PLAN_APPROVED"
        DETAIL=""
    elif [ $(_jq 'has("agentMessaged")') == "true" ]; then
        EVENT_TYPE="JULES_MESSAGE"
        DETAIL=$(_jq '.agentMessaged.prompt' | tr '\n' ' ')
    elif [ $(_jq 'has("userMessaged")') == "true" ]; then
        EVENT_TYPE="USER_MESSAGE"
        DETAIL=$(_jq '.userMessaged.prompt' | tr '\n' ' ')
    elif [ $(_jq 'has("changeSet")') == "true" ]; then
        EVENT_TYPE="CODE_ARTIFACT"
        DETAIL="Produced patch: $(_jq '.changeSet.suggestedCommitMessage // "No message"' | tr '\n' ' ')"
    elif [ $(_jq 'has("sessionCompleted")') == "true" ]; then
        EVENT_TYPE="COMPLETED"
        DETAIL=""
    elif [ $(_jq 'has("sessionFailed")') == "true" ]; then
        EVENT_TYPE="FAILED"
        DETAIL=$(_jq '.sessionFailed.reason // "Unknown failure reason"' | tr '\n' ' ')
    elif [ $(_jq 'has("progressUpdated")') == "true" ]; then
        EVENT_TYPE="PROGRESS"
        DETAIL=$(_jq '.progressUpdated.description' | tr '\n' ' ')
    else
        EVENT_TYPE=$(_jq 'keys | .[]' | grep -v -E '^(createTime|name|description)$' | head -n 1)
        if [ -z "$EVENT_TYPE" ]; then EVENT_TYPE="ACTIVITY"; fi
        DETAIL=$(_jq '.description // "No detail"' | tr '\n' ' ')
    fi

    echo "| $(date -d "$CREATE_TIME" '+%Y-%m-%d %H:%M:%S') | $EVENT_TYPE | $DETAIL |"
done

# Identify Code Outcomes
PATCHES=$(echo "$EVENTS" | jq -r 'map(select(has("changeSet")) | .changeSet)')
if [ "$PATCHES" != "null" ] && [ $(echo "$PATCHES" | jq length) -gt 0 ]; then
    echo -e "\n## 🏁 Verification & Outcome"
    echo -e "✅ Delivered $(echo "$PATCHES" | jq length) code checkpoint(s). Final patch salvaged: $(echo "$PATCHES" | jq -r '.[0].suggestedCommitMessage')"
else
    echo -e "\n## 🏁 Verification & Outcome"
    echo -e "❌ No code patches recorded in session history."
fi
