# setup.ps1

$EnvFile = ".env.jclaw"

Write-Host "=== JCLAW Agent Skills Setup ==="

# Check for Jules CLI
$JulesCliInstalled = Get-Command "jules" -ErrorAction SilentlyContinue

if (-not $JulesCliInstalled) {
    Write-Host "⚠ Jules CLI not found in PATH." -ForegroundColor Yellow
    $InstallCli = Read-Host "Would you like to install it via npm? (y/N)"
    if ($InstallCli -match "^[Yy]$") {
        npm install -g @google/jules
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Jules CLI installed successfully." -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to install Jules CLI." -ForegroundColor Red
        }
    } else {
        Write-Host "ℹ Continuing without Jules CLI (API mode only)." -ForegroundColor Cyan
    }
} else {
    Write-Host "✓ Jules CLI is available." -ForegroundColor Green
}

# Authenticate
$ApiKey = ""
if ($env:PROJECT_JULES_API_KEY) {
    Write-Host "✓ Found project-specific JULES_API_KEY." -ForegroundColor Green
    $ApiKey = $env:PROJECT_JULES_API_KEY
} elseif ($env:JULES_API_KEY) {
    Write-Host "✓ Found general JULES_API_KEY." -ForegroundColor Green
    $ApiKey = $env:JULES_API_KEY
} else {
    Write-Host "⚠ No JULES_API_KEY found in environment." -ForegroundColor Yellow
    $ApiKey = Read-Host "Please enter your Jules API Key (PAT)"
}

# Save to env file
if ($ApiKey) {
    "JULES_API_KEY=`"$ApiKey`"" | Out-File -FilePath $EnvFile -Encoding utf8
    Write-Host "✓ Saved credentials to $EnvFile." -ForegroundColor Green

    # Add to gitignore if not already present
    if (Test-Path ".gitignore") {
        $GitIgnore = Get-Content ".gitignore" -Raw
        if ($GitIgnore -notmatch "^$EnvFile$") {
            Add-Content -Path ".gitignore" -Value "`n$EnvFile"
            Write-Host "✓ Added $EnvFile to .gitignore" -ForegroundColor Green
        }
    }
} else {
    Write-Host "✗ No credentials provided. Scripts requiring API access will fail." -ForegroundColor Red
}

Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
