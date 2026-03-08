# Auto Review (`auto_review.sh` / `auto_review.ps1`)

**Usage:**
```bash
./auto_review.sh [taskId] [branch] [fixCommand] [lintCommand] [maxRetries=1]
```

**Description:**
Programmatically identifies code quality issues on a branch published by a Jules session, applies safe auto-fixes, and returns instructions to the session to address any remaining issues in a self-healing loop. This eliminates the need for the local LLM host to review mechanical syntax/lint errors or poll for completion.

**Behavior:**
- Stashes any current local changes.
- Iterates up to `maxRetries` times.
- Fetches and checks out the target `branch` published by Jules.
- Runs the `fixCommand` (e.g., `npm run format`, `npm run lint:fix`) to automatically correct safe issues.
- Runs the `lintCommand` (e.g., `npm run lint`, `npm test`) to detect remaining errors.
- If the `lintCommand` fails (non-zero exit code), it captures the output and sends it directly to the Jules session via the `sendMessage` API.
- Re-runs the `wait_for_task` script internally to pause execution until Jules replies to the feedback and updates its branch.
- Repeats the fetch -> test process until `lintCommand` succeeds or `maxRetries` is hit.
- Switches back to the original branch and restores the git stash upon exit.

**Requires:**
- Local Git repository configured and tracking the remote branch.
- `JULES_API_KEY` (configured via `setup.sh`)