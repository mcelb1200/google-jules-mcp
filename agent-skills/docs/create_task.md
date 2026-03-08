# Create Task (`create_task.sh` / `create_task.ps1`)

**Usage:**
```bash
./create_task.sh [repository] [description] [branch] [type] [marker]
```

**Description:**
Creates a new task in Google Jules with the specified repository and description. It uses the Jules REST API or the `jules` CLI to initiate the session.

**Behavior:**
- Calls `POST https://jules.googleapis.com/v1alpha/sessions` or `jules remote new`.
- Tracks the task locally if needed (by returning the `taskId`).
- Returns a success message and the new `taskId`.

**Requires:**
- `JULES_API_KEY` or `jules` CLI (configured via `setup.sh`)