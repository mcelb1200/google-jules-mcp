#!/bin/bash
# fleet_status.sh (Consolidated Fleet Dashboard for Gemini CLI)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

echo -e "${YELLOW}=== JULES AI FLEET DASHBOARD ===${NC}"

RESPONSE=$(api_call "GET" "?pageSize=50" "") || exit 1
SESSIONS=$(echo "$RESPONSE" | jq -c '.sessions // [] | .[]')

if [ -z "$SESSIONS" ]; then
    echo "No active sessions found."
    exit 0
fi

# We'll group them for easier review
PENDING_APPROVAL=""
PENDING_FEEDBACK=""
ACTIVE_PROGRESS=""
STUCK_SESSIONS=""
READY_TO_MERGE=""

STUCK_THRESHOLD_MINUTES=30
NOW_SECONDS=$(date +%s)

while IFS= read -r session; do
    ID=$(echo "$session" | jq -r '.id')
    TITLE=$(echo "$session" | jq -r '.title' | head -n 1)
    STATE=$(echo "$session" | jq -r '.state')
    UPDATE_TIME=$(echo "$session" | jq -r '.updateTime')
    BRANCH=$(echo "$session" | jq -r '.sourceContext.githubRepoContext.startingBranch // empty')
    
    # Ignore terminal states
    if [[ "$STATE" == "CANCELLED" ]] || [[ "$STATE" == "FAILED" ]]; then
        continue
    fi

    # Calc timing for stuck detection
    UPDATE_SECONDS=$(date -d "${UPDATE_TIME}" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        UPDATE_SECONDS=$(date -d "$(echo $UPDATE_TIME | sed 's/\.[0-9]*Z/Z/')" +%s 2>/dev/null)
    fi
    DIFF_MINUTES=$(( (NOW_SECONDS - UPDATE_SECONDS) / 60 ))

    # Find associated PR
    PR_LINK="No PR found"
    if [ -n "$BRANCH" ] && [ "$BRANCH" != "null" ]; then
        PR_JSON=$(gh pr list --head "$BRANCH" --json number,url,mergeable --jq '.[0]' 2>/dev/null)
        if [ -n "$PR_JSON" ] && [ "$PR_JSON" != "null" ]; then
            PR_URL=$(echo "$PR_JSON" | jq -r '.url')
            PR_NUM=$(echo "$PR_JSON" | jq -r '.number')
            PR_MERGE=$(echo "$PR_JSON" | jq -r '.mergeable')
            PR_LINK="[PR #$PR_NUM]($PR_URL) - Mergeable: $PR_MERGE"
        fi
    fi

    ENTRY="\n--- ${GREEN}Task $ID (${TITLE:0:50})${NC} ---\n"
    ENTRY+="State: [${YELLOW}${STATE}${NC}] | Updated: ${DIFF_MINUTES}m ago | $PR_LINK\n"

    case $STATE in
        "COMPLETED")
            READY_TO_MERGE+="$ENTRY"
            ;;
        "AWAITING_PLAN_APPROVAL")
            PLAN=$(api_call "GET" "/$ID/activities?pageSize=10" "" | jq -r '.activities[] | select(.planGenerated) | .planGenerated.plan.steps | map("- " + .title + ": " + .description) | join("\n")' | head -n 10)
            ENTRY+="PROPOSED PLAN:\n${BLUE}${PLAN}${NC}...\n"
            PENDING_APPROVAL+="$ENTRY"
            ;;
        "AWAITING_USER_FEEDBACK")
            QUESTION=$(api_call "GET" "/$ID/activities?pageSize=10" "" | jq -r '.activities[] | select(.agentMessaged) | .agentMessaged.agentMessage // .agentMessaged.prompt' | head -n 1)
            ENTRY+="JULES QUESTION:\n${YELLOW}> $QUESTION${NC}\n"
            PENDING_FEEDBACK+="$ENTRY"
            ;;
        "IN_PROGRESS")
            if [ $DIFF_MINUTES -gt $STUCK_THRESHOLD_MINUTES ]; then
                ENTRY+="${RED}<<< STUCK WARNING >>>${NC}\n"
                STUCK_SESSIONS+="$ENTRY"
            else
                ACTIVE_PROGRESS+="$ENTRY"
            fi
            ;;
        *)
            ACTIVE_PROGRESS+="$ENTRY"
            ;;
    esac
done <<< "$SESSIONS"

# Output organized by priority
if [ -n "$READY_TO_MERGE" ]; then
    echo -e "\n${GREEN}>>> READY FOR INTEGRATION / COMPLETED <<<${NC}"
    echo -e "$READY_TO_MERGE"
fi

if [ -n "$PENDING_APPROVAL" ]; then
    echo -e "\n${CYAN}>>> ACTIONS REQUIRED: PLAN APPROVALS <<<${NC}"
    echo -e "$PENDING_APPROVAL"
fi

if [ -n "$PENDING_FEEDBACK" ]; then
    echo -e "\n${CYAN}>>> ACTIONS REQUIRED: USER FEEDBACK <<<${NC}"
    echo -e "$PENDING_FEEDBACK"
fi

if [ -n "$STUCK_SESSIONS" ]; then
    echo -e "\n${RED}>>> WARNING: POTENTIALLY STUCK SESSIONS <<<${NC}"
    echo -e "$STUCK_SESSIONS"
fi

if [ -n "$ACTIVE_PROGRESS" ]; then
    echo -e "\n${BLUE}>>> SESSIONS IN PROGRESS <<<${NC}"
    echo -e "$ACTIVE_PROGRESS"
fi

echo -e "\n${GREEN}End of Dashboard.${NC}"
