# Wait For Task (`wait_for_task.sh` / `wait_for_task.ps1`)

**Usage:**
```bash
./wait_for_task.sh [taskId] [pollIntervalSeconds=15] [timeoutSeconds=600]
```

**Description:**
A highly efficient blocking script that polls the Jules API at a set interval until the task enters an interactive or terminal state. This prevents host LLMs from wasting significant token counts manually requesting task statuses in a loop.

**Behavior:**
- Polls `GET /sessions/{taskId}`.
- Continues blocking if the task is in `RUNNING`, `QUEUED`, `CREATING`, etc.
- Exits successfully (`0`) and returns context when the task hits `AWAITING_USER_FEEDBACK`, `AWAITING_PLAN_APPROVAL`, `COMPLETED`, or `FAILED`.
- If `AWAITING_USER_FEEDBACK` is hit, it will fetch and return the latest question from Jules.
- Exits with `2` on timeout.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)