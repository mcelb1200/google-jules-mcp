# List Tasks (`list_tasks.sh` / `list_tasks.ps1`)

**Usage:**
```bash
./list_tasks.sh [status] [repository] [limit]
```

**Description:**
Lists all active, pending, completed, or paused Jules tasks, optionally filtered by repository and status.

**Behavior:**
- Calls `GET https://jules.googleapis.com/v1alpha/sessions` or `jules remote list`.
- Returns a brief summary of tasks.

**Requires:**
- `JULES_API_KEY` or `jules` CLI (configured via `setup.sh`)