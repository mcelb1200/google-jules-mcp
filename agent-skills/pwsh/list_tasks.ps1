param(
    [string]$Status="all",
    [string]$Repository,
    [int]$Limit=10
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Listing Tasks ===" -ForegroundColor Cyan

$Response = Invoke-ApiCall -Method "GET" -Endpoint "?pageSize=$Limit"

if ($Response -and $Response.sessions) {
    foreach ($session in $Response.sessions) {
        $id = if ($session.id) { $session.id } elseif ($session.name) { ($session.name -split "/")[-1] } else { "Unknown" }
        $title = $session.title
        $state = $session.state
        Write-Host "$id - $title [$state]"
    }
} else {
    Write-Host "✗ Failed to retrieve tasks or no tasks found." -ForegroundColor Yellow
}
