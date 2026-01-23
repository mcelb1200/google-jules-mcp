<#
.SYNOPSIS
    Runs the Google Jules MCP Docker container.
.DESCRIPTION
    This script runs the Google Jules MCP Docker container, mounting the specified
    workspace path to /projects inside the container. It also passes through
    relevant environment variables.
.PARAMETER WorkspacePath
    The path to the project workspace. Defaults to the current working directory.
.EXAMPLE
    .\run_docker.ps1 -WorkspacePath "C:\MyProject"
#>

param (
    [string]$WorkspacePath = $PWD.Path
)

# Resolve absolute path
$AbsWorkspacePath = Resolve-Path $WorkspacePath | Select-Object -ExpandProperty Path

# Check if JULES_API_KEY is set; if not, try to load from .env in workspace
if (-not (Test-Path "env:JULES_API_KEY")) {
    $EnvFile = Join-Path $AbsWorkspacePath ".env"
    if (Test-Path $EnvFile) {
        $EnvContent = Get-Content $EnvFile -ErrorAction SilentlyContinue
        foreach ($Line in $EnvContent) {
            if ($Line -match "^\s*JULES_API_KEY\s*=\s*(.*)") {
                $Val = $Matches[1].Trim()
                # Remove surrounding quotes if present
                if ($Val -match "^['`"](.*)['`"]$") {
                    $Val = $Matches[1]
                }
                $Env:JULES_API_KEY = $Val
                Write-Host "Loaded JULES_API_KEY from project .env file."
                break
            }
        }
    }
}

# Check if Docker is running
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed or not in PATH."
    exit 1
}

docker info > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not running."
    exit 1
}

# Define environment variables to pass (if they exist in current session)
$EnvVars = @(
    "JULES_API_KEY",
    "SESSION_MODE",
    "BROWSERBASE_API_KEY",
    "BROWSERBASE_PROJECT_ID",
    "GOOGLE_AUTH_COOKIES"
)

$DockerArgs = @("run", "-i", "--rm")
$DockerArgs += "-v", "$($AbsWorkspacePath):/projects"
$DockerArgs += "-e", "CHROME_USER_DATA_DIR=/root/.jules-mcp/browser-data"

foreach ($Var in $EnvVars) {
    if (Test-Path "env:$Var") {
        $Val = (Get-Item "env:$Var").Value
        $DockerArgs += "-e", "$Var=$Val"
    }
}

$DockerArgs += "google-jules-mcp"

# Run Docker command
Write-Host "Running Google Jules MCP for workspace: $AbsWorkspacePath"
& docker $DockerArgs
