# Summarize Changes (`summarize_changes.sh` / `summarize_changes.ps1`)

**Usage:**
```bash
./summarize_changes.sh [branch] [baseBranch="main"]
```

**Description:**
Fetches the Jules-published branch and returns a token-efficient summary containing `git diff --stat` and the commit logs. This allows the host LLM to comprehend what files changed without parsing a potentially massive raw Git diff that could destroy its context limit.

**Behavior:**
- Fetches `origin/[branch]` and `origin/[baseBranch]`.
- Compares the logs to output commit titles and descriptions.
- Outputs `git diff --stat` to show file change counts and lines modified.

**Requires:**
- Local Git repository Tracking origin.