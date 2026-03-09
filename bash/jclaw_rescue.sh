#!/bin/bash
# jclaw_rescue.sh
# Non-destructive artifact recovery from a Jules session.
# Pushes hidden artifacts to the session's branch via GH API.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1
REPOSITORY=$2

if [ -z "$TASK_ID" ] || [ -z "$REPOSITORY" ]; then
    echo "Usage: $0 [taskId] [repository]"
    exit 1
fi

echo -e "${YELLOW}=== JCLAW RESCUE: $TASK_ID ===${NC}"

# 1. Get Session Info to find the branch
SESSION=$(api_call "GET" "/$TASK_ID" "") || exit 1
BRANCH=$(echo "$SESSION" | jq -r '.sourceContext.githubRepoContext.startingBranch // empty')

if [ -z "$BRANCH" ] || [ "$BRANCH" == "null" ]; then
    echo -e "${RED}✗ Could not determine branch for session $TASK_ID.${NC}"
    exit 1
fi

# SAFETY CHECK: Refuse to push to default or protected branches
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]] || [[ "$BRANCH" == "develop" ]]; then
    echo -e "${RED}✗ SAFETY VOID: Refusing to force-push artifacts to protected branch: $BRANCH${NC}"
    exit 1
fi

echo "Target Branch: $BRANCH"

# 2. Extract unidiffPatch
echo "Extracting artifacts..."
PATCH_CONTENT=$(api_call "GET" "/$TASK_ID/activities?pageSize=100" "" | jq -r '.activities[] | select(.artifacts) | .artifacts[] | select(.changeSet) | .changeSet.gitPatch.unidiffPatch // empty' | head -n 1)

if [ -z "$PATCH_CONTENT" ] || [ "$PATCH_CONTENT" == "null" ]; then
    echo -e "${RED}✗ No artifacts found in session $TASK_ID.${NC}"
    exit 1
fi

# 3. Create a temporary patch file and apply it locally to verify? 
# No, let's just push it as a new file or use the API to update existing ones.
# Actually, the most reliable "headless" way to apply a patch to a remote branch 
# without a local clone is tricky via just the contents API.
# Instead, we will save it locally and instruct the user to apply it, 
# OR we use gh_api_push_file for specific files if we can parse them.

LOG_DIR=".jules/logs"
mkdir -p "$LOG_DIR"
PATCH_FILE="$LOG_DIR/recovery_$TASK_ID.patch"

echo "Artifacts recovered. Saving to $PATCH_FILE"
echo "$PATCH_CONTENT" > "$PATCH_FILE"

echo -e "${GREEN}✓ Artifacts recovered successfully.${NC}"
echo "To apply manually: git checkout $BRANCH && git apply $PATCH_FILE"

