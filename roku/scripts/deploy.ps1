# Sideload the channel. ROKUPASS is read from the environment and written to a
# curl config file. It is not passed on the curl.exe command line.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$ip = if ($env:ROKU_IP) { $env:ROKU_IP } else { "192.168.86.101" }

if (-not $env:ROKUPASS) {
    Write-Error "ROKUPASS is not set. Set the developer-mode password and run this again."
    exit 2
}
if ($ip -notmatch '^[A-Za-z0-9._:-]+$') {
    Write-Error "ROKU_IP contains characters this script will not put in a URL."
    exit 2
}
if ($env:ROKUPASS.ToCharArray() | Where-Object { [int]$_ -lt 32 }) {
    Write-Error "ROKUPASS contains a control character. Choose a developer password without one."
    exit 2
}

& (Join-Path $PSScriptRoot "package.ps1") @args
$zip = Join-Path $root "dist\eaglewood.zip"

function ConvertTo-CurlQuoted([string]$value) {
    return '"' + $value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$cfg = Join-Path ([System.IO.Path]::GetTempPath()) ("eaglewood-curl-" + [guid]::NewGuid().ToString("n") + ".txt")
$body = Join-Path ([System.IO.Path]::GetTempPath()) ("eaglewood-install-" + [guid]::NewGuid().ToString("n") + ".html")
$utf8 = New-Object System.Text.UTF8Encoding $false
# Concatenate so a backtick in the password is not treated as a PowerShell escape.
$configText = @(
    "digest"
    "silent"
    "show-error"
    "connect-timeout = 10"
    "max-time = 180"
    ("user = " + (ConvertTo-CurlQuoted ("rokudev:" + $env:ROKUPASS)))
) -join "`n"
try {
    [System.IO.File]::WriteAllText($cfg, $configText + "`n", $utf8)
    Write-Host "Uploading $zip to http://${ip}/plugin_install"
    $httpCode = & curl.exe --config $cfg `
        -F "mysubmit=Install" `
        -F "archive=@${zip};filename=eaglewood.zip" `
        -F "passwd=" `
        --output $body `
        --write-out "%{http_code}" `
        "http://${ip}/plugin_install"
    $curlStatus = $LASTEXITCODE
    if ($curlStatus -ne 0 -and ([string]::IsNullOrEmpty($httpCode) -or $httpCode -eq "000")) {
        Write-Error "Could not reach the TV at $ip (curl exit $curlStatus)."
        exit 1
    }
    $response = ""
    if (Test-Path $body) {
        $response = [System.IO.File]::ReadAllText($body)
    }
    $success = $response -match "Install Success"
    $failure = $response -match "Install Failure"
    if ($httpCode -eq "401") {
        Write-Error "Authentication failed (HTTP 401). Check ROKUPASS and that developer mode is enabled."
        exit 1
    }
    if ($success -and -not $failure -and $httpCode -like "2*") {
        Write-Host "Install Success"
        exit 0
    }
    if ($response -match "Install Failure:?[^<]{0,240}") {
        Write-Host ($Matches[0] -replace "\s+", " ").Trim()
    }
    else {
        Write-Host "Installer returned HTTP $httpCode. The device did not report Install Success."
    }
    exit 1
}
finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $cfg, $body
}
