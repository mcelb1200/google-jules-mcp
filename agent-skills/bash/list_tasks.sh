#!/bin/bash
# list_tasks.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

LIMIT=${1:-10}

echo -e "${YELLOW}=== Listing Jules Tasks ===${NC}"

RESPONSE=$(api_call "GET" "?pageSize=$LIMIT" "") || exit 1
TASKS=$(echo "$RESPONSE" | jq '.sessions // []')

if [ "$TASKS" = "null" ] || [ $(echo "$TASKS" | jq length) -eq 0 ]; then
    echo "No tasks found."
    exit 0
fi

echo "$TASKS" | jq -r ".[] | {id: (.id // .name | split(\"/\") | last), title: .title, state: .state} | \"\(.id) - \(.title) [\(.state)]\"" | while read -r line; do
    if [[ "$line" == *"[COMPLETED]"* ]]; then
        echo -e "${GREEN}$line${NC}"
    elif [[ "$line" == *"[FAILED]"* ]]; then
        echo -e "${RED}$line${NC}"
    elif [[ "$line" == *"[AWAITING_USER_FEEDBACK]"* ]]; then
        echo -e "${YELLOW}$line${NC}"
    else
        echo "$line"
    fi
done
