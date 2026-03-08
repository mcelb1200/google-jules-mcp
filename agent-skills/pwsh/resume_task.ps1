param(
    [Parameter(Mandatory=$true)][string]$TaskId
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Resuming Task ===" -ForegroundColor Cyan

$BodyObj = @{
    prompt = "Please resume the task."
}
$Body = $BodyObj | ConvertTo-Json -Depth 5 -Compress

$Response = Invoke-ApiCall -Method "POST" -Endpoint "/$TaskId:sendMessage" -Body $Body

if ($Response -and -not $Response.error) {
    Write-Host "✓ Task $TaskId resumed successfully." -ForegroundColor Green
} else {
    Write-Host "✗ Failed to resume task." -ForegroundColor Red
    if ($Response) { $Response | ConvertTo-Json -Depth 5 | Write-Host }
}
