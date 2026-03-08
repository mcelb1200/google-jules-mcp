#!/bin/bash
# validate_config.sh
# Semantic Validation Gate for Jules Sessions

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

REPOSITORY=$1
BRANCH=$2
PROMPT=$3
SCOPE_FILE=$4

echo -e "${YELLOW}>>> Validating Session Configuration...${NC}"

# 1. Repository check
if [[ ! "$REPOSITORY" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
    log "error" "Invalid REPOSITORY format ($REPOSITORY). Expected 'owner/repo'."
    exit 1
fi

# 2. Branch check (requires local git)
if check_cmd "git"; then
    if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        log "warn" "Branch '$BRANCH' does not exist locally. Ensuring it exists on remote before delegation."
    fi
else
    log "warn" "Git not found. Skipping local branch validation."
fi

# 3. Prompt complexity check
PROMPT_LEN=${#PROMPT}
if [ "$PROMPT_LEN" -lt 50 ]; then
    log "warn" "Instruction prompt is very short ($PROMPT_LEN chars). Jules may require more context."
fi

# 4. Scope-lock check (AI_OPERATIONS Section 9.1 compliance)
if [ -n "$SCOPE_FILE" ]; then
    if [[ ! "$SCOPE_FILE" =~ .jules/active/.*\.md$ ]]; then
        log "error" "Scope file must be within '.jules/active/' and have '.md' extension."
        exit 1
    fi
    
    # Check for SCOPED_FILES declaration
    if ! grep -q "SCOPED_FILES" "$SCOPE_FILE"; then
        log "error" "Mandatory 'SCOPED_FILES' declaration missing from $SCOPE_FILE."
        exit 1
    fi
fi

log "info" "Semantic validation passed."
exit 0
