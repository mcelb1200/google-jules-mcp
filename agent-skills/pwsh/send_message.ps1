param(
    [Parameter(Mandatory=$true)][string]$TaskId,
    [Parameter(Mandatory=$true)][string]$Message
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Sending Message ===" -ForegroundColor Cyan

$BodyObj = @{
    prompt = $Message
}

$Body = $BodyObj | ConvertTo-Json -Depth 5 -Compress

$Response = Invoke-ApiCall -Method "POST" -Endpoint "/$TaskId:sendMessage" -Body $Body

if ($Response -and -not $Response.error) {
    Write-Host "✓ Message sent successfully to task $TaskId." -ForegroundColor Green
} else {
    Write-Host "✗ Failed to send message." -ForegroundColor Red
    if ($Response) { $Response | ConvertTo-Json -Depth 5 | Write-Host }
}
