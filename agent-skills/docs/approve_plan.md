# Approve Plan (`approve_plan.sh` / `approve_plan.ps1`)

**Usage:**
```bash
./approve_plan.sh [taskId]
```

**Description:**
Approves a generated execution plan for a given task, moving it from `AWAITING_PLAN_APPROVAL` to `RUNNING`.

**Behavior:**
- Calls `POST https://jules.googleapis.com/v1alpha/sessions/{taskId}:approvePlan`.
- Confirms the approval success to the host.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)