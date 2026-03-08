#!/bin/bash
# analyze_code.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1
RETURN_PATCH=${2:-false}

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 [taskId] [returnPatch (true|false)]"
    exit 1
fi

echo "=== Analyzing Code ==="

ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=20" "")
EVENTS=$(echo "$ACTIVITIES" | jq -r '.activities // []')

if [ "$EVENTS" = "null" ] || [ $(echo "$EVENTS" | jq length) -eq 0 ]; then
    echo "API Code Analysis for Session $TASK_ID:"
    echo "No activities found yet."
    exit 0
fi

echo "Recent Activities:"
for row in $(echo "$EVENTS" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }
    EVENT_TYPE=$(_jq 'keys | .[]' | grep -v -E '^(createTime|name|description)$' | head -n 1)
    if [ -z "$EVENT_TYPE" ]; then EVENT_TYPE="ACTIVITY"; fi
    DETAIL=$(_jq '.description // .[keys[0]].description // .[keys[0]].prompt // ""')
    echo "- $EVENT_TYPE: $DETAIL"
done

PATCHES=$(echo "$EVENTS" | jq -r 'map(select(has("changeSet")) | .changeSet)')
if [ "$PATCHES" != "null" ] && [ $(echo "$PATCHES" | jq length) -gt 0 ]; then
    LATEST_PATCH=$(echo "$PATCHES" | jq -r '.[0]')
    if [ "$RETURN_PATCH" = "true" ]; then
        echo -e "\n\n--- FULL GIT PATCH ---\n$(echo "$LATEST_PATCH" | jq -r '.gitPatch')\n\n"
    else
        echo -e "\n\n--- LATEST CODE ARTIFACT ---\nCommit Message: $(echo "$LATEST_PATCH" | jq -r '.suggestedCommitMessage // "N/A"')\nPatch Snippet (first 500 chars):\n$(echo "$LATEST_PATCH" | jq -r '.gitPatch | .[0:500]')...\n*Use returnPatch: true to get the full diff.*"
    fi
fi
