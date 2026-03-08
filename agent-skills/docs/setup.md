# Setup (`setup.sh` / `setup.ps1`)

**Usage:**
```bash
./setup.sh
```

**Description:**
Initializes the Jules CLI environment and sets required authentication credentials.

**Behavior:**
- Detects whether `jules` CLI is installed in the current `PATH`.
- Prompts for installation via `npm install -g @google/jules` if not found.
- Detects available `JULES_API_KEY`, checking `PROJECT_JULES_API_KEY` first.
- Attempts to extract cookies or OAuth credentials if applicable.
- Generates a local `.env` configuration file to cache settings for other scripts.

**Requires:**
- Node.js/NPM (for CLI install prompt)