#!/bin/bash
# delegate_task.sh (Redesigned for Headless/GH operation)

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

echo -e "${YELLOW}=== Delegating Task to Jules (Headless Mode) ===${NC}"

# Ensure we are authenticated with GH
gh auth status >/dev/null 2>&1 || { echo -e "${RED}Error: Not authenticated with gh CLI. Please run gh auth login.${NC}"; exit 1; }

# Determine Prompt (Tiered Strategy)
FINAL_PROMPT="$PROMPT"
if [ -z "$FINAL_PROMPT" ]; then
    if [ -f ".jules/active/$TASK_ID.md" ]; then
        FINAL_PROMPT=$(cat ".jules/active/$TASK_ID.md")
    elif [ -f ".jules/backlog/$TASK_ID.md" ]; then
        FINAL_PROMPT=$(cat ".jules/backlog/$TASK_ID.md")
    else
        FINAL_PROMPT="Implement changes for marker $MARKER."
    fi
fi

# Push Logic
if [ "$PUSH_FIRST" = "true" ]; then
    # 1. Commit any local changes if on the target branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" = "$BRANCH" ]; then
        if [[ -n $(git status --porcelain) ]]; then
            echo "Committing local changes on $BRANCH..."
            git add .
            git commit -m "docs(jules): preparing delegation for $TASK_ID" --no-verify || echo "Warning: Commit failed or nothing to commit."
        fi
    fi

    # 2. Push the branch (Headless)
    echo "Pushing branch $BRANCH to origin..."
    git push origin "$BRANCH" --no-verify --quiet || { echo -e "${RED}✗ git push failed. Ensure branch exists and is pushable.${NC}"; exit 1; }

    # 3. Use GH API to ensure the delegation file is present (Literal request)
    if [ -f ".jules/active/$TASK_ID.md" ]; then
        echo "Pushing delegation instructions via GH API..."
        gh_api_push_file "$REPOSITORY" "$BRANCH" ".jules/active/$TASK_ID.md" ".jules/active/$TASK_ID.md" "docs(jules): add/update delegation instructions for $TASK_ID via API" || { echo -e "${RED}✗ GH API file push failed.${NC}"; exit 1; }
    fi

    # 4. Verification (Remote SHA vs Local SHA)
    echo "Verifying remote synchronization..."
    LOCAL_SHA=$(git rev-parse "refs/heads/$BRANCH" 2>/dev/null || git rev-parse HEAD)
    REMOTE_SHA=$(gh api "repos/$REPOSITORY/branches/$BRANCH" --jq '.commit.sha' 2>/dev/null)

    if [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
        echo -e "${YELLOW}⚠ Warning: Local SHA ($LOCAL_SHA) does not match remote SHA ($REMOTE_SHA).${NC}"
        echo -e "Attempting final verification of the instruction file existence..."
    fi

    GH_FILE_PATH=".jules/active/$TASK_ID.md"
    REMOTE_FILE_CHECK=$(gh api "repos/$REPOSITORY/contents/$GH_FILE_PATH?ref=$BRANCH" --jq '.path' 2>/dev/null)
    if [ "$REMOTE_FILE_CHECK" != "$GH_FILE_PATH" ]; then
        echo -e "${RED}✗ Verification failed: Instruction file not found on remote branch $BRANCH.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Remote verification successful.${NC}"
fi

# Inject ignores and DNA (Primary Shield)
DNA_HEADER="### 🧬 Project DNA:\n- **Language**: C++17 (Strict MISRA compliance where requested)\n- **Build System**: PlatformIO\n- **Test Framework**: Google Test (GTest)\n- **Architecture**: Direct Interface Model (MidiProcessor based)\n\n"

IGNORE_TEXT=""
if [ -f ".jclaw-ignore" ]; then
    IGNORES=$(cat .jclaw-ignore | grep -v '^#' | sed 's/^/- /')
    IGNORE_TEXT="### 🛡️ Restricted Files (DO NOT MODIFY):\n$IGNORES\n\n"
fi

FINAL_PROMPT=$(printf "%b%b%s" "$DNA_HEADER" "$IGNORE_TEXT" "$FINAL_PROMPT")
FINAL_PROMPT_JSON=$(echo "$FINAL_PROMPT" | jq -Rs .)

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
  "requirePlanApproval": true,
  "automationMode": "AUTO_CREATE_PR"
}
EOF
)

RESPONSE=$(api_call "POST" "" "$BODY") || exit 1
TASK_ID_RESP=$(extract_id "$RESPONSE")

if [ "$TASK_ID_RESP" != "null" ] && [ -n "$TASK_ID_RESP" ]; then
    echo -e "${GREEN}✓ Task created successfully.${NC}"
    echo -e "Session ID: ${YELLOW}$TASK_ID_RESP${NC}"
else
    echo -e "${RED}✗ Failed to create task.${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
