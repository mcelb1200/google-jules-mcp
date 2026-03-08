# Conclude Task (`conclude_task.sh` / `conclude_task.ps1`)

**Usage:**
```bash
./conclude_task.sh [taskId] [status (completed|incomplete)] [remainingWork] [residualTaskId]
```

**Description:**
Finalizes a Jules session by moving its corresponding instruction files.

**Behavior:**
- Looks for an instruction file in `.jules/active/`.
- If `status` is `completed`, moves the file to `.jules/archive/`.
- If `status` is `incomplete`, it moves the file to `.jules/archive/` but appends a residual reference to a new file created in `.jules/backlog/` containing the `remainingWork`.
- Completes the workflow lifecycle.

**Requires:**
- Local file system access