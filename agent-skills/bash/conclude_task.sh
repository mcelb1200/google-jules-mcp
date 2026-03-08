#!/bin/bash
# conclude_task.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

TASK_ID=$1
STATUS=$2
REMAINING_WORK=$3
RESIDUAL_TASK_ID=$4

if [ -z "$TASK_ID" ] || [ -z "$STATUS" ]; then
    echo "Usage: $0 [taskId] [status (completed|incomplete)] [remainingWork] [residualTaskId]"
    exit 1
fi

echo "=== Concluding Task ==="

ACTIVE_DIR=".jules/active"
ARCHIVE_DIR=".jules/archive"
BACKLOG_DIR=".jules/backlog"

SOURCE_FILE=""
for name in "$TASK_ID" "${TASK_ID}.md" "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" "$(git rev-parse --abbrev-ref HEAD 2>/dev/null | tr '/' '-').md"; do
    if [ -n "$name" ] && [ -f "$ACTIVE_DIR/$name" ]; then
        SOURCE_FILE="$ACTIVE_DIR/$name"
        break
    fi
done

if [ -z "$SOURCE_FILE" ]; then
    SOURCE_FILE=$(find "$ACTIVE_DIR" -type f -name "*$TASK_ID*" 2>/dev/null | head -n 1)
fi

if [ -z "$SOURCE_FILE" ]; then
    echo "⚠ Could not find instruction file for $TASK_ID in $ACTIVE_DIR/. Archiving file movement skipped."
else
    mkdir -p "$ARCHIVE_DIR"
    BASE_NAME=$(basename "$SOURCE_FILE")
    TARGET_NAME=$BASE_NAME
    if [ "$STATUS" = "incomplete" ]; then
        TARGET_NAME="${TASK_ID}.incomplete.md"
        RESIDUAL_NAME=${RESIDUAL_TASK_ID:-"${TASK_ID}-residual"}
        RESIDUAL_FILE="${RESIDUAL_NAME}.md"

        # Append reference
        echo -e "\n\n### 🔄 Residual Reference\nThis task was incomplete. Remaining work is re-issued to: \`.jules/backlog/$RESIDUAL_FILE\`" >> "$SOURCE_FILE"

        # Create backlog file
        mkdir -p "$BACKLOG_DIR"
        cat <<EOF > "$BACKLOG_DIR/$RESIDUAL_FILE"
## Task: $RESIDUAL_NAME (Residual)
**Original Session**: $TASK_ID

### Remaining Work
$REMAINING_WORK
EOF
        echo "✓ Re-issued remaining work to .jules/backlog/$RESIDUAL_FILE"
    fi

    mv "$SOURCE_FILE" "$ARCHIVE_DIR/$TARGET_NAME"
    echo "✓ Archived: $ACTIVE_DIR/$BASE_NAME -> $ARCHIVE_DIR/$TARGET_NAME"
fi

echo "--- 🦞 JCLAW Conclusion ---"
echo "The pincer has released. The workflow has been successfully molted into its next state."
