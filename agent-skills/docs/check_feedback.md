# Check Feedback (`check_feedback.sh` / `check_feedback.ps1`)

**Usage:**
```bash
./check_feedback.sh [repository]
```

**Description:**
Scans all active sessions for a given repository that are in the `AWAITING_USER_FEEDBACK` state.

**Behavior:**
- Calls `GET https://jules.googleapis.com/v1alpha/sessions` to find tasks awaiting feedback.
- For each such task, fetches the most recent question from the agent.
- Output formatting is designed to be easily parsed by an LLM host so it can generate answers or prompt the user.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)