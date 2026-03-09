#!/bin/bash
# integrate_prs.sh
# Progressively integrates PRs into the current branch with QA.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

INTEGRATION_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "${YELLOW}=== JCLAW PROGRESSIVE INTEGRATOR ===${NC}"
echo "Integration Target: $INTEGRATION_BRANCH"

# List of PR numbers to integrate (ordered for least conflict)
# Specs first, then bug fixes, then features
PR_LIST=(
    1143 # wave 4 specs
    1144 # utility specs
    1149 # wave 1 specs
    1150 # wave 2 specs
    1151 # theory ghost specs
    1152 # utility specs v2
    1153 # wave 3 specs
    1148 # lfo modulation specs
    1145 # scale runner tests
    1154 # memory exhaustion fix
    1147 # serial transport impl
    1146 # bolt optimize
)

for PR in "${PR_LIST[@]}"; do
    # Skip if already in git log
    if git log --grep="integrate PR #$PR" -n 1 > /dev/null; then
        echo "ℹ PR #$PR already integrated. Skipping."
        continue
    fi
    echo -e "\n${BLUE}>>> Processing PR #$PR ...${NC}"
    
    # 1. Get PR Info
    PR_INFO=$(gh pr view "$PR" --json headRefName,title)
    PR_BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName')
    PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
    
    echo "Title: $PR_TITLE"
    echo "Branch: $PR_BRANCH"

    # 2. QA: Checkout and Test
    echo "Checking out $PR_BRANCH for QA..."
    git fetch origin "$PR_BRANCH" --quiet || { echo -e "${RED}✗ Fetch failed for PR #$PR${NC}"; continue; }
    git checkout "$PR_BRANCH" --quiet || { echo -e "${RED}✗ Checkout failed for PR #$PR${NC}"; continue; }
    
    echo "Running native tests..."
    # Using a subset of tests or full suite depending on time
    pio test -e native > .jules/qa_results_pr_$PR.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ QA Passed for PR #$PR${NC}"
        
        # 3. Merge into integration branch
        git checkout "$INTEGRATION_BRANCH" --quiet
        echo "Merging PR #$PR into $INTEGRATION_BRANCH..."
        git merge "$PR_BRANCH" -m "chore(integration): integrate PR #$PR - $PR_TITLE" --no-edit
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Integrated PR #$PR${NC}"
        else
            echo -e "${RED}✗ Merge conflict in PR #$PR. Manual resolution required.${NC}"
            # Attempt to abort merge
            git merge --abort
        fi
    else
        echo -e "${RED}✗ QA Failed for PR #$PR. Check .jules/qa_results_pr_$PR.log${NC}"
        git checkout "$INTEGRATION_BRANCH" --quiet
    fi
done

echo -e "\n${YELLOW}=== Integration Summary ===${NC}"
git log main..HEAD --oneline --graph
