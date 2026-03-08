#!/bin/bash
# diagnose.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

echo -e "${YELLOW}=== JCLAW Diagnosis Tool ===${NC}\n"

# 1. Check Dependencies
echo -e "${YELLOW}[1/4] Checking dependencies...${NC}"
deps=("curl" "jq" "git" "base64")
for dep in "${deps[@]}"; do
    if check_cmd "$dep"; then
        echo -e "${GREEN}✓ $dep is installed.${NC}"
    else
        echo -e "${RED}✗ $dep is missing.${NC}"
    fi
done

# 2. Check Credentials
echo -e "\n${YELLOW}[2/4] Checking credentials...${NC}"
if [ -n "$JULES_API_KEY" ]; then
    echo -e "${GREEN}✓ JULES_API_KEY is set.${NC}"
else
    echo -e "${RED}✗ JULES_API_KEY is not set. Run setup.sh first.${NC}"
fi

# 3. Check Connectivity
echo -e "\n${YELLOW}[3/4] Checking Jules API connectivity...${NC}"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "https://jules.googleapis.com/v1alpha/sessions?pageSize=1" \
    -H "x-goog-api-key: $JULES_API_KEY" \
    -H "Content-Type: application/json")

if [[ "$RESPONSE" -eq 200 ]]; then
    echo -e "${GREEN}✓ Successfully connected to Jules API.${NC}"
else
    echo -e "${RED}✗ Failed to connect to Jules API (HTTP $RESPONSE).${NC}"
fi

# 4. Check Workspace structure
echo -e "\n${YELLOW}[4/4] Checking .jules/ structure...${NC}"
required_dirs=(".jules/active" ".jules/backlog" ".jules/archive")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ $dir directory found.${NC}"
    else
        echo -e "${YELLOW}! $dir directory is missing (Normal if no tasks started).${NC}"
    fi
done

echo -e "\n${GREEN}Diagnosis Complete.${NC}"
