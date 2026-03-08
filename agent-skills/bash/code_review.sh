#!/bin/bash
# code_review.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 [taskId]"
    exit 1
fi

echo "=== Extracting Code Review ==="

ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=50" "")
EVENTS=$(echo "$ACTIVITIES" | jq -r '.activities // []')

if [ "$EVENTS" = "null" ] || [ $(echo "$EVENTS" | jq length) -eq 0 ]; then
    echo "❌ No activities found for session $TASK_ID."
    exit 1
fi

REVIEW=""
for row in $(echo "$EVENTS" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }
    DETAIL=$(_jq '.progressUpdated.description // .description')
    if [[ "$DETAIL" == *"Analysis and Reasoning"* ]] || [[ "$DETAIL" == *"Evaluation of the Solution"* ]] || [[ "$DETAIL" == *"Merge Assessment"* ]] || [[ "$DETAIL" == *"#Correct#" ]] || [[ "$DETAIL" == *"#Incomplete#" ]]; then
        REVIEW="$DETAIL"
        break
    fi
done

if [ -n "$REVIEW" ]; then
    echo -e "## 🔍 Latest Code Review for Session $TASK_ID\n\n$REVIEW"
else
    echo -e "❌ No formal code review found in the session history for $TASK_ID.\n\nYou can instruct Jules to perform a review by sending a message:\n\"Please perform a final code review and provide a merge assessment.\""
fi
