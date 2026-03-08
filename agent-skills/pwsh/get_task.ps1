param(
    [Parameter(Mandatory=$true)][string]$TaskId
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Getting Task Details ===" -ForegroundColor Cyan

$Response = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId"

if ($Response) {
    $State = $Response.state
    if (-not $State) {
        Write-Host "✗ Failed to retrieve task state." -ForegroundColor Red
        $Response | ConvertTo-Json -Depth 5 | Write-Host
        exit 1
    }

    Write-Host "Task ID: $TaskId"
    Write-Host "Title: $($Response.title)"
    Write-Host "State: $State"

    if ($State -eq "AWAITING_USER_FEEDBACK") {
        Write-Host "⚠ Task is awaiting user feedback." -ForegroundColor Yellow
        Write-Host "Fetching latest agent message..." -ForegroundColor Cyan

        $ActivitiesResp = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId/activities?pageSize=10"
        if ($ActivitiesResp -and $ActivitiesResp.activities) {
            $LatestMessageObj = $ActivitiesResp.activities | Where-Object { $_.agentMessaged } | Select-Object -First 1
            if ($LatestMessageObj) {
                Write-Host "`nJULES QUESTION:" -ForegroundColor Yellow
                Write-Host $LatestMessageObj.agentMessaged.prompt
            } else {
                Write-Host "Failed to retrieve the latest message from Jules." -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "✗ Request failed." -ForegroundColor Red
}
