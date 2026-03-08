#!/bin/bash
# create_task.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

REPOSITORY=$1
DESCRIPTION=$2
BRANCH=${3:-"main"}

if [ -z "$REPOSITORY" ] || [ -z "$DESCRIPTION" ]; then
    echo "Usage: $0 [repository] [description] [branch]"
    exit 1
fi

echo "=== Creating Task ==="
DESCRIPTION_ESCAPED=$(echo "$DESCRIPTION" | jq -Rs .)

TITLE=$(echo "$DESCRIPTION" | head -n 1 | cut -c 1-50 | jq -Rs .)

BODY=$(cat <<EOF
{
  "prompt": $DESCRIPTION_ESCAPED,
  "sourceContext": {
    "source": "sources/github/$REPOSITORY",
    "githubRepoContext": {
      "startingBranch": "$BRANCH"
    }
  },
  "title": $TITLE,
  "requirePlanApproval": true
}
EOF
)

RESPONSE=$(api_call "POST" "" "$BODY")
TASK_ID=$(echo "$RESPONSE" | jq -r '.id // .name | split("/") | last')

if [ "$TASK_ID" != "null" ]; then
    echo "✓ Task created successfully. Session ID: $TASK_ID"
else
    echo "✗ Failed to create task. Response:"
    echo "$RESPONSE" | jq '.'
fi
