# Resume Task (`resume_task.sh` / `resume_task.ps1`)

**Usage:**
```bash
./resume_task.sh [taskId]
```

**Description:**
Resumes a paused or interrupted Jules task. Under the hood, this sends a "resume" command via the sendMessage endpoint if it's waiting for feedback, or otherwise continues execution.

**Behavior:**
- Uses the sendMessage endpoint with a generic "Please resume the task." string.
- Returns confirmation.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)