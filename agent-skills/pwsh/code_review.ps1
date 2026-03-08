param(
    [Parameter(Mandatory=$true)][string]$TaskId
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Extracting Code Review ===" -ForegroundColor Cyan

$ActivitiesResp = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId/activities?pageSize=50"
$Events = if ($ActivitiesResp -and $ActivitiesResp.activities) { $ActivitiesResp.activities } else { @() }

if (-not $Events -or $Events.Count -eq 0) {
    Write-Host "❌ No activities found for session $TaskId." -ForegroundColor Red
    exit 1
}

$Review = ""
foreach ($a in $Events) {
    $Detail = if ($a.progressUpdated -and $a.progressUpdated.description) { $a.progressUpdated.description } else { $a.description }
    if ($Detail) {
        if ($Detail -match "Analysis and Reasoning" -or $Detail -match "Evaluation of the Solution" -or $Detail -match "Merge Assessment" -or $Detail -match "#Correct#" -or $Detail -match "#Incomplete#") {
            $Review = $Detail
            break
        }
    }
}

if ($Review) {
    Write-Host "## 🔍 Latest Code Review for Session $TaskId`n`n$Review"
} else {
    Write-Host "❌ No formal code review found in the session history for $TaskId.`n`nYou can instruct Jules to perform a review by sending a message:`n`"Please perform a final code review and provide a merge assessment.`"" -ForegroundColor Yellow
}
