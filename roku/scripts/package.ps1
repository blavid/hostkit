# Zip the channel with manifest at the archive root.
# The guest path key is written only into the staged copy of secrets.brs.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$channel = Join-Path $root "channel"
$out = Join-Path $root "dist"
$zipPath = Join-Path $out "eaglewood.zip"
$limit = 4MB

function Invoke-Python([string[]]$PyArgs) {
    $python = $null
    foreach ($name in @("python3", "python")) {
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            $python = $name
            break
        }
    }
    if (-not $python) {
        Write-Error "Python is required to package guest secrets."
        exit 2
    }
    & $python @PyArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$noGuest = $false
$stub = ""
$index = 0
while ($index -lt $args.Count) {
    $arg = [string]$args[$index]
    if ($arg -eq "--no-guest") {
        $noGuest = $true
        $index += 1
        continue
    }
    if ($arg -eq "--stub") {
        if ($index + 1 -ge $args.Count) {
            Write-Error "--stub requires a guest.json URL."
            exit 2
        }
        $stub = [string]$args[$index + 1]
        $index += 2
        continue
    }
    Write-Error "Unknown argument."
    exit 2
}
if ($noGuest -and $stub -ne "") {
    Write-Error "Use either --no-guest or --stub, not both."
    exit 2
}

Invoke-Python @((Join-Path $PSScriptRoot "check_tracked_guest_key.py"))

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("eaglewood-stage-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
try {
    Copy-Item -Path (Join-Path $channel "*") -Destination $stage -Recurse -Force
    $secrets = Join-Path $stage "components\secrets.brs"
    if (Test-Path $secrets) { Remove-Item -Force $secrets }
    $writer = Join-Path $PSScriptRoot "write_guest_secrets.py"
    if ($noGuest) {
        Invoke-Python @($writer, "--dest", $secrets, "--no-guest")
    }
    elseif ($stub -ne "") {
        $env:GUEST_STUB_URL = $stub
        try {
            Invoke-Python @($writer, "--dest", $secrets, "--stub-from-env")
        }
        finally {
            Remove-Item Env:GUEST_STUB_URL -ErrorAction SilentlyContinue
        }
    }
    else {
        Invoke-Python @($writer, "--dest", $secrets, "--key-from-env")
    }

    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $snapshot = Join-Path $out "snapshot"
    Invoke-Python @((Join-Path $PSScriptRoot "guide_snapshot.py"), "--into-stage", $stage, "--snapshot-dir", $snapshot)
    if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -Path $stage -Recurse -File | ForEach-Object {
            if ($_.Name -eq ".DS_Store") { return }
            $relative = $_.FullName.Substring($stage.Length).TrimStart("\", "/").Replace("\", "/")
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $_.FullName,
                $relative,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stage
}

$bytes = (Get-Item $zipPath).Length
Write-Host "Packaged $zipPath ($bytes bytes)"
if ($bytes -gt $limit) {
    Write-Error "Package is $bytes bytes, over the 4 MB certification limit."
    exit 1
}
