# Google Jules MCP - Docker Setup

This directory contains the Docker setup for running the Google Jules MCP server.

## Prerequisites

- Docker
- Docker Compose (optional, but recommended)

## Building the Image

```bash
docker build -t JCLAW .
```

## Running the Container

The container requires the active project to be mounted to `/projects`.

### Option 1: Using Helper Scripts (Recommended for IDEs)

We provide helper scripts that automatically mount the provided path (or current directory) to `/projects`.

**Windows (Batch):**
```cmd
scripts\run_docker.bat "C:\path\to\your\project"
```

**Windows (PowerShell):**
```powershell
.\scripts\run_docker.ps1 -WorkspacePath "C:\path\to\your\project"
```

**macOS/Linux (Bash):**
```bash
chmod +x scripts/run_docker.sh
./scripts/run_docker.sh "/path/to/your/project"
```

### Option 2: Manual Docker Run

```bash
docker run -i \
  -v /path/to/your/project:/projects \
  -e JULES_API_KEY=your_api_key \
  -e SESSION_MODE=fresh \
  JCLAW
```

## IDE Integration

To configure your IDE (e.g., Claude Desktop, VS Code) to pass the active project to the container:

### 1. Claude Desktop (Manual Config)
Edit your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "jclaw": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-v",
        "/absolute/path/to/your/project:/projects",
        "-e",
        "JULES_API_KEY=your_key_here",
        "JCLAW"
      ]
    }
  }
}
```
*Note: Claude Desktop currently requires absolute paths in the config file.*

### 2. VS Code (Generic MCP Extension)
If your extension supports variable expansion (like `${workspaceFolder}`), point it to the wrapper script:

*   **Command:** `path/to/JCLAW/scripts/run_docker.bat` (or `.sh`)
*   **Args:** `${workspaceFolder}`

## Configuration

The following environment variables can be passed to the container:

-   `WORKSPACE_DIR`: The directory where `jules` CLI commands are executed (default: `/projects`).
-   `JULES_CLI_PATH`: Path to the Jules CLI executable (default: `jules`).
-   `SESSION_MODE`: `fresh`, `chrome-profile`, `cookies`, `persistent`, or `browserbase`.
-   `HEADLESS`: `true` or `false` (default: `true`).
-   `DEBUG`: `true` or `false`.