---
name: jclaw
description: Orchestrate Google Jules for autonomous coding tasks, code reviews, and repository management. Use when delegating long-running refactors, auditing Jules sessions, or retrieving code analysis from remote Jules executions.
---

# JCLAW (Jules Crustacean Logic & Automated Workflow)

This skill provides a suite of tools for the "Lobster Pattern" where you (the Brain) orchestrate Jules (the Muscles) in a remote VM.

## Core Workflow

### 1. Delegation
To offload a task to Jules, use `delegate_task.sh`. This is the primary entry point for autonomous work.

```bash
./agent-skills/bash/delegate_task.sh [repository] [branch] [taskId] [instruction]
```

- **repository**: e.g., `owner/repo`
- **branch**: The feature branch Jules should work on.
- **instruction**: Detailed prompt for Jules. If omitted, the script looks for `@jules` markers or `.jules/backlog/` files.

### 2. Monitoring & Feedback
Check the status of your tasks and respond to feedback if Jules gets stuck.

- **List Tasks**: `./agent-skills/bash/list_tasks.sh`
- **Check Feedback**: `./agent-skills/bash/check_feedback.sh` (Looks for `AWAITING_USER_FEEDBACK`)
- **Approve Plan**: `./agent-skills/bash/approve_plan.sh [taskId]` (Approves the execution plan)
- **Send Message**: `./agent-skills/bash/send_message.sh [taskId] [message]`

### 3. Verification & Conclusion
Once Jules finishes, audit the work and conclude the session.

- **Audit Report**: `./agent-skills/bash/audit_report.sh [taskId]` (Generates a report in `.jules/audit/`)
- **Code Review**: `./agent-skills/bash/code_review.sh [taskId]` (Retrieves Jules' self-review)
- **Analyze Changes**: `./agent-skills/bash/analyze_code.sh [taskId]` (Shows the diff and changes)
- **Conclude**: `./agent-skills/bash/conclude_task.sh [taskId] [completed|incomplete]`

## Best Practices
- **Token Efficiency**: Use these scripts to avoid long-running polling in your own context.
- **Context Preservation**: Jules works on a remote branch; always audit the changes before merging to main.
- **Setup**: Ensure `JULES_API_KEY` is set. Run `./agent-skills/bash/setup.sh` to verify.
