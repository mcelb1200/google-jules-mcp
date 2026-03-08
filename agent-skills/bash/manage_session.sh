#!/bin/bash
# manage_session.sh
# Interactive Session Management Interface for JCLAW

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"
source "$DIR/github_integration.sh"

echo -e "${YELLOW}=== JCLAW Session Management ===${NC}\n"

while true; do
    # 1. Fetch sessions
    echo -e "Fetching sessions..."
    RESPONSE=$(api_call "GET" "?pageSize=10" "") || exit 1
    SESSIONS=$(echo "$RESPONSE" | jq '.sessions // []')
    
    if [ "$SESSIONS" = "null" ] || [ $(echo "$SESSIONS" | jq length) -eq 0 ]; then
        echo -e "${RED}No active sessions found.${NC}"
        break
    fi

    # 2. Display selection table
    echo -e "\n${YELLOW}ID   | TITLE                           | STATE${NC}"
    echo -e "--------------------------------------------------------"
    
    COUNT=0
    declare -A SESSION_MAP
    
    while read -r line; do
        ID=$(echo "$line" | cut -d' ' -f1)
        TITLE=$(echo "$line" | cut -d'|' -f2 | xargs)
        STATE=$(echo "$line" | cut -d'|' -f3 | xargs)
        
        SESSION_MAP[$COUNT]=$ID
        
        # Color state
        COLOR_STATE=$STATE
        if [[ "$STATE" == "COMPLETED" ]]; then COLOR_STATE="${GREEN}$STATE${NC}"; fi
        if [[ "$STATE" == "FAILED" ]]; then COLOR_STATE="${RED}$STATE${NC}"; fi
        if [[ "$STATE" == "AWAITING_USER_FEEDBACK" ]]; then COLOR_STATE="${YELLOW}$STATE${NC}"; fi
        
        printf "%-4d | %-31s | %b\n" $COUNT "${TITLE:0:30}" "$COLOR_STATE"
        ((COUNT++))
    done < <(echo "$SESSIONS" | jq -r '.[] | "\(.id // .name | split("/") | last) | \(.title) | \(.state)"')

    echo -e "\n${YELLOW}Commands:${NC} [0-$(($COUNT-1))] Select Task | [q] Quit | [r] Refresh"
    read -p "Select action: " CHOICE

    if [[ "$CHOICE" == "q" ]]; then break; fi
    if [[ "$CHOICE" == "r" ]]; then continue; fi
    
    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [[ "$CHOICE" -lt $COUNT ]]; then
        TASK_ID=${SESSION_MAP[$CHOICE]}
        
        # Sub-menu for task
        while true; do
            echo -e "\n${GREEN}>>> Task $TASK_ID Options:${NC}"
            echo -e "1) View Latest Feedback / Message"
            echo -e "2) Approve Execution Plan"
            echo -e "3) Reply to Jules"
            echo -e "4) View Associated GitHub PR"
            echo -e "5) Generate Audit Report & Conclude"
            echo -e "6) Back to Task List"
            read -p "Selection: " SUB_CHOICE
            
            case $SUB_CHOICE in
                1) 
                    echo -e "\n${YELLOW}Fetching latest activity...${NC}"
                    ACTIVITIES=$(api_call "GET" "/$TASK_ID/activities?pageSize=10" "")
                    MSG=$(echo "$ACTIVITIES" | jq -r '.activities // [] | .[] | select(.agentMessaged) | .agentMessaged.agentMessage' | head -n 1)
                    if [ "$MSG" != "null" ]; then echo -e "\n${GREEN}Jules says:${NC}\n$MSG"; else echo "No messages found."; fi
                    ;;
                2)
                    "$DIR/approve_plan.sh" "$TASK_ID"
                    ;;
                3)
                    read -p "Enter your message: " MSG
                    "$DIR/send_message.sh" "$TASK_ID" "$MSG"
                    ;;
                4)
                    # Use GitHub Integration
                    SESSION_DATA=$(api_call "GET" "/$TASK_ID" "")
                    REPO=$(echo "$SESSION_DATA" | jq -r '.sourceContext.source | sub("sources/github/"; "")')
                    BRANCH=$(echo "$SESSION_DATA" | jq -r '.sourceContext.githubRepoContext.startingBranch')
                    echo -e "\nChecking for PR for branch ${YELLOW}$BRANCH${NC} in ${YELLOW}$REPO${NC}..."
                    PR_LINK=$(get_session_pr_link "$BRANCH" "$REPO")
                    echo -e "Result: ${GREEN}$PR_LINK${NC}"
                    ;;
                5)
                    "$DIR/audit_report.sh" "$TASK_ID"
                    read -p "Mark as (completed/incomplete): " STATUS
                    "$DIR/conclude_task.sh" "$TASK_ID" "$STATUS"
                    break 2
                    ;;
                6) break ;;
                *) echo "Invalid choice." ;;
            esac
        done
    else
        echo -e "${RED}Invalid selection.${NC}"
    fi
done
