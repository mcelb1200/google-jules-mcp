#!/bin/bash
# summarize_changes.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

BRANCH=$1
BASE_BRANCH=${2:-main}

if [ -z "$BRANCH" ]; then
    echo "Usage: $0 [branch] [base_branch]"
    exit 1
fi

echo "=== Summarizing Changes on $BRANCH vs $BASE_BRANCH ==="

# Fetch branches
git fetch origin "$BRANCH" >/dev/null 2>&1 || true
git fetch origin "$BASE_BRANCH" >/dev/null 2>&1 || true

# Check if branch exists
if ! git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
    echo "✗ Branch origin/$BRANCH does not exist."
    exit 1
fi

if ! git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
    echo "⚠ Warning: Base branch origin/$BASE_BRANCH not found. Trying local $BASE_BRANCH..."
    BASE_REF="$BASE_BRANCH"
else
    BASE_REF="origin/$BASE_BRANCH"
fi

# Compare
COMMITS=$(git log "$BASE_REF..origin/$BRANCH" --oneline)
if [ -z "$COMMITS" ]; then
    echo "No new commits on $BRANCH compared to $BASE_REF."
    exit 0
fi

echo -e "\n--- Commit Summary ---"
echo "$COMMITS"

echo -e "\n--- Diff Stat ---"
git diff --stat "$BASE_REF..origin/$BRANCH"

echo -e "\n--- End Summary ---"
