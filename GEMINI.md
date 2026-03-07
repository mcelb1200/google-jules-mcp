# 🤖 JCLAW (Jules Crustacean Logic & Automated Workflow)

JCLAW is an MCP server designed to orchestrate **Google Jules**, providing high-level reasoning (Brain) with autonomous remote execution (Muscles).

## 🚀 The Lobster Pattern

JCLAW promotes the **Lobster Pattern** where YOU (the agent) provide the brain and context, while Jules (the muscles) performs the heavy-lifting refactors in a remote VM.

### 🧠 Brain / 🦞 Muscles Workflow:
1. **Context/Instruction**: You define what needs to be done.
2. **Delegation**: Use `/jules:delegate` to trigger a remote Jules task.
3. **Execution**: Jules completes the task autonomously on a remote branch.
4. **Audit/Merge**: You audit the results using `/jules:audit` and merge if successful.

## 🛠️ Commands

You can use the following slash commands within the Gemini CLI:

- `/jules:delegate [instruction]` - Delegate a task to Jules using instructions from `@jules` markers or `.jules/active/` files.
- `/jules:status` - List currently active Jules tasks and their progress.
- `/jules:audit [taskId]` - Generate a comprehensive audit report for a completed session.
- `/jules:review [taskId]` - Extract the most recent code review reasoning from a Jules session.
- `/jules:feedback` - Check if any Jules tasks are awaiting user feedback.
- `/jules:conclude [taskId] [status]` - Finalize a Jules session (status: `completed` or `incomplete`).

## ⚙️ Configuration

Ensure the following environment variables are set for the Gemini CLI if you want to use API mode (10x faster):

- `JULES_API_KEY`: Your Jules Personal Access Token.
- `JULES_CLI_PATH`: Path to the `jules` binary.
- `SESSION_MODE`: Default is `browserbase` for remote execution.

## 📁 Repository Structure

JCLAW looks for instructions in:
- `.jules/backlog/` (Pending tasks)
- `.jules/active/` (Running tasks)
- `@jules` markers in the source code.

Audit reports are saved to `.jules/audit/`.
