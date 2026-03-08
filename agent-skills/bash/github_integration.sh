#!/bin/bash
# github_integration.sh
# Professional helper for mapping Jules sessions to GitHub PRs

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DIR/common.sh"

# Find a PR associated with a branch
get_pr_for_branch() {
    local branch=$1
    local repo=$2
    if ! check_cmd "gh"; then return 1; fi
    
    gh pr list --head "$branch" --repo "$repo" --json number,url,title --jq '.[0]'
}

# Post a comment to a PR
post_pr_comment() {
    local pr_number=$1
    local repo=$2
    local body=$3
    if ! check_cmd "gh"; then return 1; fi

    gh pr comment "$pr_number" --repo "$repo" --body "$body"
}

# Link a Jules session to a PR (helper for audit reports)
get_session_pr_link() {
    local branch=$1
    local repo=$2
    local pr_json=$(get_pr_for_branch "$branch" "$repo")
    
    if [ -n "$pr_json" ] && [ "$pr_json" != "null" ]; then
        local url=$(echo "$pr_json" | jq -r '.url')
        local num=$(echo "$pr_json" | jq -r '.number')
        echo "[PR #$num]($url)"
    else
        echo "No PR found for branch $branch"
    fi
}
