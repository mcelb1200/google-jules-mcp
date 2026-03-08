param(
    [Parameter(Mandatory=$true)][string]$TaskId
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Approving Plan ===" -ForegroundColor Cyan

$BodyObj = @{}
$Body = $BodyObj | ConvertTo-Json -Depth 5 -Compress

$Response = Invoke-ApiCall -Method "POST" -Endpoint "/$TaskId:approvePlan" -Body "{}"

if ($Response -and -not $Response.error) {
    Write-Host "✓ Plan approved successfully for task $TaskId." -ForegroundColor Green
} else {
    Write-Host "✗ Failed to approve plan." -ForegroundColor Red
    if ($Response) { $Response | ConvertTo-Json -Depth 5 | Write-Host }
}
