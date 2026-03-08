param(
    [Parameter(Mandatory=$true)][string]$TaskId,
    [bool]$ReturnPatch=$false
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Analyzing Code ===" -ForegroundColor Cyan

$ActivitiesResp = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId/activities?pageSize=20"
$Events = if ($ActivitiesResp -and $ActivitiesResp.activities) { $ActivitiesResp.activities } else { @() }

if (-not $Events -or $Events.Count -eq 0) {
    Write-Host "API Code Analysis for Session $TaskId:"
    Write-Host "No activities found yet."
    exit 0
}

Write-Host "Recent Activities:"
foreach ($a in $Events) {
    $keys = $a.psobject.properties.name | Where-Object { $_ -notmatch '^(createTime|name|description)$' }
    $EventType = if ($keys -and $keys.Count -gt 0) { $keys[0] } else { "ACTIVITY" }

    $Detail = if ($a.description) { $a.description } else { "" }
    if (-not $Detail -and $keys -and $keys.Count -gt 0) {
        $obj = $a.$EventType
        if ($obj) {
            if ($obj.description) { $Detail = $obj.description }
            elseif ($obj.prompt) { $Detail = $obj.prompt }
        }
    }
    Write-Host "- $EventType: $Detail"
}

$Patches = $Events | Where-Object { $_.changeSet } | Select-Object -ExpandProperty changeSet
if ($Patches -and $Patches.Count -gt 0) {
    $LatestPatch = $Patches[0]
    if ($ReturnPatch) {
        Write-Host "`n`n--- FULL GIT PATCH ---`n$($LatestPatch.gitPatch)`n`n"
    } else {
        $CommitMsg = if ($LatestPatch.suggestedCommitMessage) { $LatestPatch.suggestedCommitMessage } else { "N/A" }
        $Snippet = if ($LatestPatch.gitPatch -and $LatestPatch.gitPatch.Length -gt 500) { $LatestPatch.gitPatch.Substring(0, 500) } else { $LatestPatch.gitPatch }
        Write-Host "`n`n--- LATEST CODE ARTIFACT ---`nCommit Message: $CommitMsg`nPatch Snippet (first 500 chars):`n$Snippet...`n*Use ReturnPatch = `$true to get the full diff.*"
    }
}
