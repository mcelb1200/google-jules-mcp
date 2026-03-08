param(
    [Parameter(Mandatory=$true)][string]$Repository,
    [Parameter(Mandatory=$true)][string]$Description,
    [string]$Branch="main",
    [string]$Type="standard",
    [string]$Marker="@jules"
)

$Dir = Split-Path $MyInvocation.MyCommand.Path
. "$Dir\common.ps1"

Write-Host "=== Creating Task ===" -ForegroundColor Cyan

$TitleStr = if ($Description.Length -gt 50) { $Description.Substring(0, 50) } else { $Description }

$BodyObj = @{
    prompt = $Description
    sourceContext = @{
        source = "sources/github/$Repository"
        githubRepoContext = @{
            startingBranch = $Branch
        }
    }
    title = $TitleStr
    requirePlanApproval = $true
}

$Body = $BodyObj | ConvertTo-Json -Depth 5 -Compress

$Response = Invoke-ApiCall -Method "POST" -Endpoint "" -Body $Body

if ($Response) {
    $TaskId = if ($Response.id) { $Response.id } elseif ($Response.name) { ($Response.name -split "/")[-1] } else { $null }
    if ($TaskId) {
        Write-Host "✓ Task created successfully. Session ID: $TaskId" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to extract task ID from response." -ForegroundColor Red
        $Response | ConvertTo-Json -Depth 5 | Write-Host
    }
} else {
    Write-Host "✗ Request failed." -ForegroundColor Red
}
