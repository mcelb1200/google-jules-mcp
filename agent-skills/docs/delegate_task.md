# Delegate Task (`delegate_task.sh` / `delegate_task.ps1`)

**Usage:**
```bash
./delegate_task.sh [repository] [branch] [taskId] [prompt] [pushFirst (true|false)] [marker]
```

**Description:**
The most efficient way to initiate a delegated task. This script will push the current branch to origin (optional), and trigger a Jules task using the provided prompt, marker, or instruction file. It bypasses complex MCP checks in favor of a direct, long-running REST API call to `https://jules.googleapis.com/v1alpha/sessions`.

**Behavior:**
- Pushes the branch if `pushFirst` is true.
- Resolves the prompt by checking provided text, an instruction file, or falling back to a `@jules` marker in the codebase.
- Creates a new session in Jules for the given `repository` and `branch`.
- Returns the new `taskId` and a summary of the action.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)