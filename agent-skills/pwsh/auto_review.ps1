param(
    [Parameter(Mandatory=$true)][string]$TaskId,
    [Parameter(Mandatory=$true)][string]$Branch,
    [Parameter(Mandatory=$true)][string]$FixCommand,
    [Parameter(Mandatory=$true)][string]$LintCommand,
    [int]$MaxRetries=1
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Automated Code Review ===" -ForegroundColor Cyan

$CurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
$StashNeeded = $false

$DiffExitCode = (git diff-index --quiet HEAD --; $LASTEXITCODE)
if ($DiffExitCode -ne 0) {
    Write-Host "ℹ Stashing local changes..." -ForegroundColor Yellow
    git stash push -m "auto_review_stash_$TaskId" | Out-Null
    $StashNeeded = $true
}

$RetryCount = 0

while ($RetryCount -le $MaxRetries) {
    Write-Host "--- Attempt $($RetryCount + 1) of $($MaxRetries + 1) ---" -ForegroundColor Cyan

    Write-Host "ℹ Fetching remote branch: $Branch" -ForegroundColor Cyan
    git fetch origin $Branch | Out-Null

    git checkout $Branch | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to checkout branch $Branch. Does it exist locally or on origin?" -ForegroundColor Red
        break
    }

    Write-Host "ℹ Pulling latest changes from origin..." -ForegroundColor Cyan
    git pull origin $Branch | Out-Null

    Write-Host "ℹ Running fix command: $FixCommand" -ForegroundColor Cyan
    Invoke-Expression $FixCommand | Out-Null

    Write-Host "ℹ Running lint command: $LintCommand" -ForegroundColor Cyan
    $LintOutput = ""
    try {
        $LintOutput = Invoke-Expression $LintCommand 2>&1 | Out-String
        $LintExitCode = $LASTEXITCODE
    } catch {
        $LintOutput = $_.Exception.Message
        $LintExitCode = 1
    }

    if ($LintExitCode -eq 0) {
        Write-Host "✓ Code passed automated review." -ForegroundColor Green
        break
    }

    Write-Host "✗ Code quality issues found." -ForegroundColor Yellow

    if ($RetryCount -ge $MaxRetries) {
        Write-Host "⚠ Maximum retries reached ($MaxRetries). Stopping review loop." -ForegroundColor Yellow
        break
    }

    Write-Host "ℹ Preparing feedback for Jules session..." -ForegroundColor Cyan
    $TruncatedOutput = if ($LintOutput.Length -gt 10000) { $LintOutput.Substring(0, 10000) } else { $LintOutput }
    $Feedback = "Automated Code Review Failed. Please address the following programmatic errors identified by the CI/Linter on branch \`$Branch\`:`n`n\`\`\``n$TruncatedOutput`n\`\`\``n`nPlease fix these issues and update the plan or commit the fixes."

    $BodyObj = @{ prompt = $Feedback }
    $Body = $BodyObj | ConvertTo-Json -Depth 5 -Compress

    Write-Host "ℹ Sending feedback to session $TaskId..." -ForegroundColor Cyan
    $Response = Invoke-ApiCall -Method "POST" -Endpoint "/$TaskId:sendMessage" -Body $Body

    if ($Response -and -not $Response.error) {
        Write-Host "✓ Feedback sent successfully. Waiting for Jules to address issues..." -ForegroundColor Green

        # Delegate to wait_for_task script natively
        & "$Dir\wait_for_task.ps1" -TaskId $TaskId -Interval 15 -TimeoutSeconds 600
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠ Waiting timed out or failed. Stopping loop." -ForegroundColor Yellow
            break
        }
    } else {
        Write-Host "✗ Failed to send feedback to Jules. Stopping loop." -ForegroundColor Red
        if ($Response) { $Response | ConvertTo-Json -Depth 5 | Write-Host }
        break
    }

    $RetryCount++
}

Write-Host "ℹ Restoring original branch: $CurrentBranch" -ForegroundColor Cyan
git checkout $CurrentBranch | Out-Null

if ($StashNeeded) {
    Write-Host "ℹ Popping stashed changes..." -ForegroundColor Yellow
    git stash pop | Out-Null
}

Write-Host "=== Auto Review Complete ===" -ForegroundColor Cyan
