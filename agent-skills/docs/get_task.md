# Get Task Details (`get_task.sh` / `get_task.ps1`)

**Usage:**
```bash
./get_task.sh [taskId]
```

**Description:**
Retrieves the current state, title, and latest messages of a specific Jules task.

**Behavior:**
- Calls `GET https://jules.googleapis.com/v1alpha/sessions/{taskId}`.
- If the task is awaiting user feedback, it also fetches the latest agent message.
- Returns a structured output with state information.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)