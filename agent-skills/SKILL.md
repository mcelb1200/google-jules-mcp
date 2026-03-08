---
name: jclaw
description: Orchestrate Google Jules for autonomous coding tasks, code reviews, and repository management. Use when delegating long-running refactors, auditing Jules sessions, or retrieving code analysis from remote Jules executions.
---

# JCLAW (Jules Crustacean Logic & Automated Workflow)

Professional suite for the "Lobster Pattern" where you (the Brain) orchestrate Jules (the Muscles) in a remote environment.

## Professional Workflow

### 1. Delegation
Initialize autonomous work on a specific repository branch.
```bash
./agent-skills/bash/delegate_task.sh [repository] [branch] [taskId] [instruction]
```
- **repository**: `owner/repo`
- **branch**: The feature branch for Jules.
- **instruction**: Detailed prompt or use `@jules` markers in code.

### 2. Session Management (Interactive)
The primary tool for monitoring, replying to, and approving Jules' work.
```bash
./agent-skills/bash/manage_session.sh
```
- **Interactive Interface**: Select tasks to view feedback, approve plans, or reply.
- **GitHub Integration**: Automatically identifies and links associated Pull Requests.

### 3. Verification & Auditing
Generate comprehensive reports and conclude sessions.
```bash
./agent-skills/bash/audit_report.sh [taskId]
```
- **Enhanced Reports**: Generates `.jules/audit/[taskId].report.md` with full conversation history and PR links.
- **Conclusion**: Use `./agent-skills/bash/conclude_task.sh` to archive instructions and transition state.

## Core Utilities
- **`diagnose.sh`**: Verify environment, dependencies, and API connectivity.
- **`analyze_code.sh`**: Review diffs and summarized code changes.
- **`github_integration.sh`**: Library for PR mapping and automated comments.

## Best Practices
- **PR Centricity**: Always check the associated GitHub PR (linked in `manage_session.sh`) before approving execution plans.
- **Context Integrity**: Audit the final report in `.jules/audit/` before merging any Jules-generated branch to `main`.
- **Token Efficiency**: Use the interactive manager to minimize active polling turns.
