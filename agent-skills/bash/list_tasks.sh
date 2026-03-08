#!/bin/bash
# list_tasks.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

STATUS=$1
REPOSITORY=$2
LIMIT=${3:-10}

echo "=== Listing Tasks ==="

RESPONSE=$(api_call "GET" "?pageSize=$LIMIT" "")
TASKS=$(echo "$RESPONSE" | jq '.sessions // []')

if [ "$TASKS" = "null" ]; then
    echo "✗ Failed to retrieve tasks."
    echo "$RESPONSE" | jq '.'
    exit 1
fi

echo "$TASKS" | jq -r '.[].id // .name | split("/") | last as $id | .title as $title | .state as $state | "\($id) - \($title) [\($state)]"'
