# common.ps1

$EnvFile = ".env.jclaw"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^(.*?)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2] -replace '^"(.*)"$', '$1'
            Set-Item -Path Env:\$name -Value $value
        }
    }
}

$Global:ApiKey = $env:JULES_API_KEY
if (-not $Global:ApiKey) {
    Write-Host "Error: JULES_API_KEY not found. Please run setup.ps1 first." -ForegroundColor Red
    exit 1
}

$Global:ApiBase = "https://jules.googleapis.com/v1alpha/sessions"

function Invoke-ApiCall {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$Body
    )

    $Headers = @{
        "x-goog-api-key" = $Global:ApiKey
        "Content-Type" = "application/json"
    }

    $Url = "$Global:ApiBase$Endpoint"

    try {
        if ($Method -eq "GET") {
            return Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers -ErrorAction Stop
        } else {
            return Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers -Body $Body -ErrorAction Stop
        }
    } catch {
        Write-Error "API Call Failed: $_"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.ReadToEnd()
        }
        return $null
    }
}
