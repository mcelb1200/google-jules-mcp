#!/bin/bash
# delegate_task.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

REPOSITORY=$1
BRANCH=$2
TASK_ID=$3
PROMPT=$4
PUSH_FIRST=${5:-true}
MARKER=${6:-"@jules"}

if [ -z "$REPOSITORY" ] || [ -z "$BRANCH" ]; then
    echo "Usage: $0 [repository] [branch] [taskId] [prompt] [pushFirst (true|false)] [marker]"
    exit 1
fi

echo "=== Delegating Task ==="

if [ "$PUSH_FIRST" = "true" ]; then
    echo "Pushing branch $BRANCH to origin..."
    git push origin "$BRANCH" || echo "⚠ Push failed or skipped."
fi

# Determine Prompt (Tiered Strategy)
FINAL_PROMPT="$PROMPT"
if [ -z "$FINAL_PROMPT" ]; then
    if [ -f ".jules/active/$TASK_ID.md" ]; then
        FINAL_PROMPT=$(cat ".jules/active/$TASK_ID.md")
        echo "ℹ Using prompt from .jules/active/$TASK_ID.md"
    elif [ -f ".jules/backlog/$TASK_ID.md" ]; then
        FINAL_PROMPT=$(cat ".jules/backlog/$TASK_ID.md")
        echo "ℹ Using prompt from .jules/backlog/$TASK_ID.md"
    else
        FINAL_PROMPT="I have added code markers starting with '$MARKER' in this branch. Please scan the repository, find these markers, and implement the requested changes for each one. Once found, remove the markers as you implement the fixes."
        echo "ℹ Using marker-based prompt."
    fi
fi

# Inject ignores (Primary Shield)
IGNORE_TEXT=""
if [ -f ".jclaw-ignore" ]; then
    IGNORES=$(cat .jclaw-ignore | grep -v '^#' | sed 's/^/- /')
    IGNORE_TEXT="\n\n### 🛡️ Restricted Files (DO NOT MODIFY):\n$IGNORES"
fi

FINAL_PROMPT=$(printf "%s%b" "$FINAL_PROMPT" "$IGNORE_TEXT")
FINAL_PROMPT=$(echo "$FINAL_PROMPT" | jq -Rs .) # Escape JSON string

TITLE="[Delegated] ${TASK_ID:-$BRANCH}"
TITLE=$(echo "$TITLE" | jq -Rs .)

echo "Initiating Jules API request..."

BODY=$(cat <<EOF
{
  "prompt": $FINAL_PROMPT,
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

echo "$RESPONSE" | jq '.'

TASK_ID_RESP=$(echo "$RESPONSE" | jq -r '.id // .name | split("/") | last')

if [ "$TASK_ID_RESP" != "null" ]; then
    echo "✓ Task created successfully. Session ID: $TASK_ID_RESP"
else
    echo "✗ Failed to create task."
fi
