# JCLAW Agent Skills Summary

This package provides direct bash and PowerShell tools for interacting with the Google Jules AI coding assistant API and CLI, bypassing the need for a full MCP server setup.

These scripts are designed for token-efficient, long-running orchestration by an LLM host.

## Skill Tiers

### Tier 1: Core Operations (The Muscles)
*These are the fundamental actions you will take most often to offload mechanical work to Jules.*

- [**Delegate Task**](delegate_task.md): Initiate a delegated task on a branch.
- [**Create Task**](create_task.md): Create a new Jules session.
- [**Get Task Details**](get_task.md): Retrieve the current state of a task.
- [**List Tasks**](list_tasks.md): View all active/pending tasks.
- [**Send Message**](send_message.md): Send instructions or context to an active task.

### Tier 2: Workflow Orchestration (The Brain)
*These skills handle the lifecycle, feedback loop, and verification of tasks.*

- [**Check Feedback**](check_feedback.md): Scan tasks for `AWAITING_USER_FEEDBACK` status.
- [**Approve Plan**](approve_plan.md): Approve a generated execution plan.
- [**Resume Task**](resume_task.md): Resume a paused session.
- [**Audit Report**](audit_report.md): Generate a formal audit report for a session.
- [**Conclude Task**](conclude_task.md): Finalize a session (completed or incomplete) and archive instructions.
- [**Code Review**](code_review.md): Extract the latest code review from a session's history.

### Tier 3: Advanced Utility
*Scripts for specific, complex scenarios or bulk operations.*

- [**Analyze Code**](analyze_code.md): Retrieve code changes and diffs from a session.
- [**Setup**](setup.md): Initialize environment variables and CLI tools.
