@echo off
setlocal

:: This script runs the Google Jules MCP Docker container.
:: Usage: run_docker.bat [path_to_workspace]
:: If no path is provided, the current directory is used.

set "WORKSPACE_PATH=%~1"
if "%WORKSPACE_PATH%"=="" set "WORKSPACE_PATH=%CD%"

:: Check if JULES_API_KEY is set; if not, try to load from .env in workspace
if "%JULES_API_KEY%"=="" (
    if exist "%WORKSPACE_PATH%\.env" (
        for /f "usebackq tokens=1* delims==" %%A in ("%WORKSPACE_PATH%\.env") do (
            if "%%A"=="JULES_API_KEY" (
                :: Simple trimming of quotes is hard in batch, assuming clean input or basic quotes
                set "JULES_API_KEY=%%B"
                echo Loaded JULES_API_KEY from project .env file.
            )
        )
    )
)

:: Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Docker is not running or not installed. >&2
    exit /b 1
)

:: Run the container
:: -i: Keep stdin open (required for MCP stdio transport)
:: --rm: Remove container after exit
:: -v: Mount workspace
:: -e: Pass environment variables (ensure these are set in your IDE/environment or add them here)

docker run -i --rm ^
  -v "%WORKSPACE_PATH%:/projects" ^
  -e JULES_API_KEY=%JULES_API_KEY% ^
  -e SESSION_MODE=%SESSION_MODE% ^
  -e BROWSERBASE_API_KEY=%BROWSERBASE_API_KEY% ^
  -e BROWSERBASE_PROJECT_ID=%BROWSERBASE_PROJECT_ID% ^
  -e GOOGLE_AUTH_COOKIES=%GOOGLE_AUTH_COOKIES% ^
  -e CHROME_USER_DATA_DIR=/root/.jules-mcp/browser-data ^
  google-jules-mcp

endlocal
