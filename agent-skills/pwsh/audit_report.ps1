param(
    [Parameter(Mandatory=$true)][string]$TaskId
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Generating Audit Report ===" -ForegroundColor Cyan

$SessionResp = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId"

if (-not $SessionResp -or $SessionResp.error) {
    Write-Host "✗ Failed to fetch session." -ForegroundColor Red
    if ($SessionResp) { $SessionResp | ConvertTo-Json -Depth 5 | Write-Host }
    exit 1
}

$Title = $SessionResp.title
$State = $SessionResp.state
$Source = if ($SessionResp.sourceContext -and $SessionResp.sourceContext.source) { $SessionResp.sourceContext.source } else { "Unknown" }
$Prompt = if ($SessionResp.prompt) { $SessionResp.prompt } else { "No initial prompt record available." }

$ActivitiesResp = Invoke-ApiCall -Method "GET" -Endpoint "/$TaskId/activities?pageSize=50"

$Events = if ($ActivitiesResp -and $ActivitiesResp.activities) { $ActivitiesResp.activities } else { @() }

Write-Host "# 🛡️ Jules Session Audit Report`n"
Write-Host "**Session ID**: `$TaskId`"
Write-Host "**Title**: $Title"
Write-Host "**Final State**: `$State`"
Write-Host "**Repository**: $Source"
Write-Host "**Generated At**: $(Get-Date)`n"
Write-Host "## 📝 Intent Statement (Initial Prompt)`n> $Prompt`n"
Write-Host "## 🔄 Delivery Activity Log`n| Timestamp | Event Type | Details |`n| :--- | :--- | :--- |"

foreach ($a in $Events) {
    $CreateTime = $a.createTime
    $EventType = "ACTIVITY"
    $Detail = "No detail"

    if ($a.planGenerated) {
        $EventType = "PLAN_GENERATED"
        $count = if ($a.planGenerated.steps) { $a.planGenerated.steps.Count } else { 0 }
        $Detail = "Plan contains $count steps."
    } elseif ($a.planApproved) {
        $EventType = "PLAN_APPROVED"
        $Detail = ""
    } elseif ($a.agentMessaged) {
        $EventType = "JULES_MESSAGE"
        $Detail = $a.agentMessaged.prompt -replace "`n", " "
    } elseif ($a.userMessaged) {
        $EventType = "USER_MESSAGE"
        $Detail = $a.userMessaged.prompt -replace "`n", " "
    } elseif ($a.changeSet) {
        $EventType = "CODE_ARTIFACT"
        $msg = if ($a.changeSet.suggestedCommitMessage) { $a.changeSet.suggestedCommitMessage } else { "No message" }
        $Detail = "Produced patch: $msg" -replace "`n", " "
    } elseif ($a.sessionCompleted) {
        $EventType = "COMPLETED"
        $Detail = ""
    } elseif ($a.sessionFailed) {
        $EventType = "FAILED"
        $reason = if ($a.sessionFailed.reason) { $a.sessionFailed.reason } else { "Unknown failure reason" }
        $Detail = $reason -replace "`n", " "
    } elseif ($a.progressUpdated) {
        $EventType = "PROGRESS"
        $Detail = $a.progressUpdated.description -replace "`n", " "
    } else {
        $keys = $a.psobject.properties.name | Where-Object { $_ -notmatch '^(createTime|name|description)$' }
        if ($keys -and $keys.Count -gt 0) {
            $EventType = $keys[0]
            $obj = $a.$EventType
            if ($obj -and $obj.description) {
                $Detail = $obj.description
            } elseif ($obj -and $obj.prompt) {
                $Detail = $obj.prompt
            }
        }
        if ($a.description) { $Detail = $a.description }
        $Detail = $Detail -replace "`n", " "
    }

    $dt = [datetime]::Parse($CreateTime).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "| $dt | $EventType | $Detail |"
}

$Patches = $Events | Where-Object { $_.changeSet } | Select-Object -ExpandProperty changeSet

if ($Patches -and $Patches.Count -gt 0) {
    Write-Host "`n## 🏁 Verification & Outcome"
    $msg = if ($Patches[0].suggestedCommitMessage) { $Patches[0].suggestedCommitMessage } else { "No message" }
    Write-Host "✅ Delivered $($Patches.Count) code checkpoint(s). Final patch salvaged: $msg"
} else {
    Write-Host "`n## 🏁 Verification & Outcome"
    Write-Host "❌ No code patches recorded in session history."
}
