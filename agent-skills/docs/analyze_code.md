# Analyze Code (`analyze_code.sh` / `analyze_code.ps1`)

**Usage:**
```bash
./analyze_code.sh [taskId] [returnPatch (true|false)]
```

**Description:**
Retrieves a summary of code changes or the raw Git patch produced by Jules in a given session.

**Behavior:**
- Calls the session activities endpoint.
- Finds `changeSet` artifacts to salvage the suggested code.
- If `returnPatch` is true, returns the raw diff block; otherwise, returns the commit message and snippet summary.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)