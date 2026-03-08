param(
    [Parameter(Mandatory=$true)][string]$Repository,
    [Parameter(Mandatory=$true)][string]$Branch,
    [string]$TaskId,
    [string]$Prompt,
    [bool]$PushFirst=$true,
    [string]$Marker="@jules"
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Delegating Task ===" -ForegroundColor Cyan

if ($PushFirst) {
    Write-Host "Pushing branch $Branch to origin..." -ForegroundColor Yellow
    git push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠ Push failed or skipped." -ForegroundColor Yellow
    }
}

# Determine Prompt (Tiered Strategy)
$FinalPrompt = $Prompt
if (-not $FinalPrompt) {
    if (Test-Path ".jules/active/$TaskId.md") {
        $FinalPrompt = Get-Content ".jules/active/$TaskId.md" -Raw
        Write-Host "ℹ Using prompt from .jules/active/$TaskId.md" -ForegroundColor Cyan
    } elseif (Test-Path ".jules/backlog/$TaskId.md") {
        $FinalPrompt = Get-Content ".jules/backlog/$TaskId.md" -Raw
        Write-Host "ℹ Using prompt from .jules/backlog/$TaskId.md" -ForegroundColor Cyan
    } else {
        $FinalPrompt = "I have added code markers starting with '$Marker' in this branch. Please scan the repository, find these markers, and implement the requested changes for each one. Once found, remove the markers as you implement the fixes."
        Write-Host "ℹ Using marker-based prompt." -ForegroundColor Cyan
    }
}

# Inject ignores (Primary Shield)
$IgnoreText = ""
if (Test-Path ".jclaw-ignore") {
    $Ignores = Get-Content ".jclaw-ignore" | Where-Object { $_ -notmatch '^#' -and $_ -ne "" } | ForEach-Object { "- $_" }
    if ($Ignores) {
        $IgnoreText = "`n`n### 🛡️ Restricted Files (DO NOT MODIFY):`n" + ($Ignores -join "`n")
    }
}

$FinalPrompt = $FinalPrompt + $IgnoreText

$TitleStr = if ($TaskId) { "[Delegated] $TaskId" } else { "[Delegated] $Branch" }

Write-Host "Initiating Jules API request..." -ForegroundColor Cyan

$BodyObj = @{
    prompt = $FinalPrompt
    sourceContext = @{
        source = "sources/github/$Repository"
        githubRepoContext = @{
            startingBranch = $Branch
        }
    }
    title = $TitleStr
    requirePlanApproval = $true
}

$Body = $BodyObj | ConvertTo-Json -Depth 5 -Compress

$Response = Invoke-ApiCall -Method "POST" -Endpoint "" -Body $Body

if ($Response) {
    $TaskIdResp = if ($Response.id) { $Response.id } elseif ($Response.name) { ($Response.name -split "/")[-1] } else { $null }
    if ($TaskIdResp) {
        Write-Host "✓ Task created successfully. Session ID: $TaskIdResp" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to extract task ID from response." -ForegroundColor Red
        $Response | ConvertTo-Json -Depth 5 | Write-Host
    }
} else {
    Write-Host "✗ Request failed." -ForegroundColor Red
}
