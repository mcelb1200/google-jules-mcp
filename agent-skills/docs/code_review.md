# Code Review (`code_review.sh` / `code_review.ps1`)

**Usage:**
```bash
./code_review.sh [taskId]
```

**Description:**
Extracts the latest code review or merge assessment from a session's activity list.

**Behavior:**
- Calls the session activities endpoint.
- Filters for `progressUpdated` or description updates containing terms like "Analysis and Reasoning", "Evaluation", "Merge Assessment", etc.
- Returns the full text of the review.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)