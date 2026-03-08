param(
    [Parameter(Mandatory=$true)][string]$TaskId,
    [int]$Interval=15,
    [int]$TimeoutSeconds=600
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Waiting for Task $TaskId ===" -ForegroundColor Cyan
$StartTime = Get-Date

while ($true) {
    $Response = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId"
    $State = $Response.state

    if (-not $State) {
        Write-Host "✗ Failed to retrieve task state." -ForegroundColor Red
        exit 1
    }

    Write-Host "Current State: $State" -NoNewline
    Write-Host "`r" -NoNewline # Overwrite line next loop unless broken

    $TargetStates = @("COMPLETED", "FAILED", "AWAITING_USER_FEEDBACK", "AWAITING_PLAN_APPROVAL")
    if ($TargetStates -contains $State) {
        Write-Host "`n✓ Task has reached an interactive or terminal state: $State" -ForegroundColor Green

        if ($State -eq "AWAITING_USER_FEEDBACK") {
            $ActivitiesResp = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId/activities?pageSize=10"
            if ($ActivitiesResp -and $ActivitiesResp.activities) {
                $LatestMessageObj = $ActivitiesResp.activities | Where-Object { $_.agentMessaged } | Select-Object -First 1
                if ($LatestMessageObj) {
                    Write-Host "JULES QUESTION:" -ForegroundColor Yellow
                    Write-Host $LatestMessageObj.agentMessaged.prompt
                }
            }
        }
        exit 0
    }

    $CurrentTime = Get-Date
    $Elapsed = ($CurrentTime - $StartTime).TotalSeconds
    if ($Elapsed -ge $TimeoutSeconds) {
        Write-Host "`n⚠ Timeout reached ($TimeoutSeconds seconds). Task is still in $State." -ForegroundColor Yellow
        exit 2
    }

    Start-Sleep -Seconds $Interval
}
