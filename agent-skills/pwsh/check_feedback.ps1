param(
    [string]$Repository
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Checking Feedback ===" -ForegroundColor Cyan

$Response = Invoke-ApiCall -Method "GET" -Endpoint "?pageSize=50"

if ($Response -and $Response.sessions) {
    $Tasks = $Response.sessions | Where-Object { $_.state -eq "AWAITING_USER_FEEDBACK" }

    if (-not $Tasks -or $Tasks.Count -eq 0) {
        Write-Host "No sessions currently require user feedback." -ForegroundColor Green
        exit 0
    }

    Write-Host "The following tasks require your feedback:" -ForegroundColor Yellow

    foreach ($Task in $Tasks) {
        $TaskId = if ($Task.id) { $Task.id } elseif ($Task.name) { ($Task.name -split "/")[-1] } else { "Unknown" }
        $Title = $Task.title

        Write-Host "`n--- Task $TaskId ($Title) ---" -ForegroundColor Cyan

        $ActivitiesResp = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId/activities?pageSize=10"
        if ($ActivitiesResp -and $ActivitiesResp.activities) {
            $LatestMessageObj = $ActivitiesResp.activities | Where-Object { $_.agentMessaged } | Select-Object -First 1
            if ($LatestMessageObj) {
                Write-Host "> $($LatestMessageObj.agentMessaged.prompt)"
            } else {
                Write-Host "> Jules is awaiting feedback, but no message was found." -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "No sessions currently require user feedback." -ForegroundColor Green
}
