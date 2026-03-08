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
    echo "Example: $0 google/jules main task123"
    exit 1
fi

echo -e "${YELLOW}=== Delegating Task to Jules ===${NC}"

# Pre-flight check: Repository structure
if [[ "$REPOSITORY" != */* ]]; then
    echo -e "${RED}Error: REPOSITORY must be in 'owner/repo' format.${NC}"
    exit 1
fi

if [ "$PUSH_FIRST" = "true" ]; then
    echo "Pushing branch $BRANCH to origin..."
    git push origin "$BRANCH" || { echo -e "${RED}✗ Push failed. Aborting delegation.${NC}"; exit 1; }
fi

# Determine Prompt (Tiered Strategy)
FINAL_PROMPT="$PROMPT"
if [ -z "$FINAL_PROMPT" ]; then
    if [ -f ".jules/active/$TASK_ID.md" ]; then
        FINAL_PROMPT=$(cat ".jules/active/$TASK_ID.md")
        echo -e "ℹ ${GREEN}Using prompt from .jules/active/$TASK_ID.md${NC}"
    elif [ -f ".jules/backlog/$TASK_ID.md" ]; then
        FINAL_PROMPT=$(cat ".jules/backlog/$TASK_ID.md")
        echo -e "ℹ ${GREEN}Using prompt from .jules/backlog/$TASK_ID.md${NC}"
    else
        FINAL_PROMPT="I have added code markers starting with '$MARKER' in this branch. Please scan the repository, find these markers, and implement the requested changes for each one. Once found, remove the markers as you implement the fixes."
        echo -e "ℹ ${GREEN}Using marker-based prompt ($MARKER)${NC}"
    fi
fi

# Inject ignores (Primary Shield)
IGNORE_TEXT=""
if [ -f ".jclaw-ignore" ]; then
    IGNORES=$(cat .jclaw-ignore | grep -v '^#' | sed 's/^/- /')
    IGNORE_TEXT="\n\n### 🛡️ Restricted Files (DO NOT MODIFY):\n$IGNORES"
    echo -e "ℹ ${YELLOW}Injecting .jclaw-ignore restrictions${NC}"
fi

FINAL_PROMPT=$(printf "%s%b" "$FINAL_PROMPT" "$IGNORE_TEXT")
FINAL_PROMPT_JSON=$(echo "$FINAL_PROMPT" | jq -Rs .) # Escape JSON string

TITLE="[Delegated] ${TASK_ID:-$BRANCH}"
TITLE_JSON=$(echo "$TITLE" | jq -Rs .)

echo "Initiating Jules API request..."

BODY=$(cat <<EOF
{
  "prompt": $FINAL_PROMPT_JSON,
  "sourceContext": {
    "source": "sources/github/$REPOSITORY",
    "githubRepoContext": {
      "startingBranch": "$BRANCH"
    }
  },
  "title": $TITLE_JSON,
  "requirePlanApproval": true
}
EOF
)

RESPONSE=$(api_call "POST" "" "$BODY") || exit 1

TASK_ID_RESP=$(extract_id "$RESPONSE")

if [ "$TASK_ID_RESP" != "null" ] && [ -n "$TASK_ID_RESP" ]; then
    echo -e "${GREEN}✓ Task created successfully.${NC}"
    echo -e "Session ID: ${YELLOW}$TASK_ID_RESP${NC}"
    echo -e "Title: $TITLE"
else
    echo -e "${RED}✗ Failed to create task.${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
