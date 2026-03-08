param(
    [Parameter(Mandatory=$true)][string]$TaskId,
    [Parameter(Mandatory=$true)][ValidateSet("completed", "incomplete")][string]$Status,
    [string]$RemainingWork="",
    [string]$ResidualTaskId=""
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Concluding Task ===" -ForegroundColor Cyan

$ActiveDir = ".jules\active"
$ArchiveDir = ".jules\archive"
$BacklogDir = ".jules\backlog"

$SourceFile = ""

# Try to find the file
$Branch = git rev-parse --abbrev-ref HEAD 2>$null
$BranchDashed = if ($Branch) { $Branch -replace "/", "-" } else { "" }

$PossibleNames = @(
    $TaskId,
    "$TaskId.md",
    $Branch,
    "$Branch.md",
    $BranchDashed,
    "$BranchDashed.md"
)

foreach ($Name in $PossibleNames) {
    if ($Name -and (Test-Path "$ActiveDir\$Name")) {
        $SourceFile = "$ActiveDir\$Name"
        break
    }
}

if (-not $SourceFile) {
    $Files = Get-ChildItem -Path $ActiveDir -Filter "*$TaskId*" -File -ErrorAction SilentlyContinue
    if ($Files -and $Files.Count -gt 0) {
        $SourceFile = $Files[0].FullName
    }
}

if (-not $SourceFile) {
    Write-Host "⚠ Could not find instruction file for $TaskId in $ActiveDir\. Archiving file movement skipped." -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
    $BaseName = Split-Path -Leaf $SourceFile
    $TargetName = $BaseName

    if ($Status -eq "incomplete") {
        $TargetName = "$TaskId.incomplete.md"
        $ResidualName = if ($ResidualTaskId) { $ResidualTaskId } else { "$TaskId-residual" }
        $ResidualFile = "$ResidualName.md"

        $AppendText = "`n`n### 🔄 Residual Reference`nThis task was incomplete. Remaining work is re-issued to: \`.jules/backlog/$ResidualFile\`"
        Add-Content -Path $SourceFile -Value $AppendText

        New-Item -ItemType Directory -Force -Path $BacklogDir | Out-Null
        $BacklogContent = "## Task: $ResidualName (Residual)`n**Original Session**: $TaskId`n`n### Remaining Work`n$RemainingWork"
        Set-Content -Path "$BacklogDir\$ResidualFile" -Value $BacklogContent
        Write-Host "✓ Re-issued remaining work to $BacklogDir\$ResidualFile" -ForegroundColor Green
    }

    Move-Item -Path $SourceFile -Destination "$ArchiveDir\$TargetName" -Force
    Write-Host "✓ Archived: $ActiveDir\$BaseName -> $ArchiveDir\$TargetName" -ForegroundColor Green
}

Write-Host "--- 🦞 JCLAW Conclusion ---" -ForegroundColor Cyan
Write-Host "The pincer has released. The workflow has been successfully molted into its next state." -ForegroundColor Cyan
