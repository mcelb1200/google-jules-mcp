param(
    [Parameter(Mandatory=$true)][string]$Branch,
    [string]$BaseBranch="main"
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Summarizing Changes on $Branch vs $BaseBranch ===" -ForegroundColor Cyan

# Fetch branches
git fetch origin $Branch | Out-Null
git fetch origin $BaseBranch | Out-Null

$BranchExists = git rev-parse --verify "origin/$Branch" 2>$null
if (-not $BranchExists) {
    Write-Host "✗ Branch origin/$Branch does not exist." -ForegroundColor Red
    exit 1
}

$BaseExists = git rev-parse --verify "origin/$BaseBranch" 2>$null
if (-not $BaseExists) {
    Write-Host "⚠ Warning: Base branch origin/$BaseBranch not found. Trying local $BaseBranch..." -ForegroundColor Yellow
    $BaseRef = $BaseBranch
} else {
    $BaseRef = "origin/$BaseBranch"
}

$Commits = git log "$BaseRef..origin/$Branch" --oneline
if (-not $Commits) {
    Write-Host "No new commits on $Branch compared to $BaseRef." -ForegroundColor Green
    exit 0
}

Write-Host "`n--- Commit Summary ---" -ForegroundColor Cyan
Write-Host $Commits

Write-Host "`n--- Diff Stat ---" -ForegroundColor Cyan
git diff --stat "$BaseRef..origin/$Branch"

Write-Host "`n--- End Summary ---" -ForegroundColor Cyan
