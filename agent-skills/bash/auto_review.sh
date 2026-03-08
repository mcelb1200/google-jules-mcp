#!/bin/bash
# auto_review.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1
BRANCH=$2
FIX_COMMAND=$3
LINT_COMMAND=$4
MAX_RETRIES=${5:-1}

if [ -z "$TASK_ID" ] || [ -z "$BRANCH" ] || [ -z "$FIX_COMMAND" ] || [ -z "$LINT_COMMAND" ]; then
    echo "Usage: $0 [taskId] [branch] \"[fixCommand]\" \"[lintCommand]\" [maxRetries=1]"
    exit 1
fi

echo "=== Automated Code Review ==="

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
STASH_NEEDED=false

if ! git diff-index --quiet HEAD --; then
    echo "ℹ Stashing local changes..."
    git stash push -m "auto_review_stash_$TASK_ID" >/dev/null
    STASH_NEEDED=true
fi

RETRY_COUNT=0

while [ "$RETRY_COUNT" -le "$MAX_RETRIES" ]; do
    echo "--- Attempt $(($RETRY_COUNT + 1)) of $(($MAX_RETRIES + 1)) ---"

    echo "ℹ Fetching remote branch: $BRANCH"
    git fetch origin "$BRANCH" >/dev/null 2>&1

    if ! git checkout "$BRANCH" >/dev/null 2>&1; then
        echo "✗ Failed to checkout branch $BRANCH. Does it exist locally or on origin?"
        break
    fi

    echo "ℹ Pulling latest changes from origin..."
    git pull origin "$BRANCH" >/dev/null 2>&1 || true

    echo "ℹ Running fix command: $FIX_COMMAND"
    eval "$FIX_COMMAND" >/dev/null 2>&1

    echo "ℹ Running lint command: $LINT_COMMAND"
    LINT_OUTPUT=$(eval "$LINT_COMMAND" 2>&1)
    LINT_EXIT_CODE=$?

    if [ $LINT_EXIT_CODE -eq 0 ]; then
        echo "✓ Code passed automated review."
        break
    fi

    echo "✗ Code quality issues found."

    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "⚠ Maximum retries reached ($MAX_RETRIES). Stopping review loop."
        break
    fi

    echo "ℹ Preparing feedback for Jules session..."
    TRUNCATED_OUTPUT=$(echo "$LINT_OUTPUT" | cut -c 1-10000)
    FEEDBACK="Automated Code Review Failed. Please address the following programmatic errors identified by the CI/Linter on branch \`$BRANCH\`:\n\n\`\`\`\n$TRUNCATED_OUTPUT\n\`\`\`\n\nPlease fix these issues and update the plan or commit the fixes."
    FEEDBACK_ESCAPED=$(echo -e "$FEEDBACK" | jq -Rs .)
    BODY=$(cat <<EOF
{
  "prompt": $FEEDBACK_ESCAPED
}
EOF
    )

    echo "ℹ Sending feedback to session $TASK_ID..."
    RESPONSE=$(api_call "POST" "/$TASK_ID:sendMessage" "$BODY")

    if echo "$RESPONSE" | jq -e 'has("error")' > /dev/null; then
        echo "✗ Failed to send feedback to Jules. Stopping loop."
        break
    fi

    echo "✓ Feedback sent. Waiting for Jules to address issues..."
    # Delegate to wait_for_task script
    bash "$DIR/wait_for_task.sh" "$TASK_ID" 15 600
    WAIT_EXIT=$?

    if [ $WAIT_EXIT -ne 0 ]; then
        echo "⚠ Waiting timed out or failed. Stopping loop."
        break
    fi

    RETRY_COUNT=$(($RETRY_COUNT + 1))
done

echo "ℹ Restoring original branch: $CURRENT_BRANCH"
git checkout "$CURRENT_BRANCH" >/dev/null 2>&1

if [ "$STASH_NEEDED" = true ]; then
    echo "ℹ Popping stashed changes..."
    git stash pop >/dev/null 2>&1
fi

echo "=== Auto Review Complete ==="
