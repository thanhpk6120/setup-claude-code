# install.ps1 - One-line installer for setup-claude-code
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (-not $env:AI_BASE_URL) {
    $env:AI_BASE_URL = "http://localhost:20128/v1"
}

$zipUrl = "https://github.com/thanhpk6120/setup-claude-code/archive/refs/heads/main.zip"
$tempBase = Join-Path $env:TEMP ("claude-code-install-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("claude-code-repo-" + [System.Guid]::NewGuid().ToString("N") + ".zip")

try {
    Write-Host "==> Downloading setup-claude-code package from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    Write-Host "==> Extracting files..." -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath $tempBase -Force

    $extractedRoot = Join-Path $tempBase "setup-claude-code-main"
    if (-not (Test-Path $extractedRoot)) {
        $found = Get-ChildItem -Directory $tempBase | Select-Object -First 1
        if ($found) { $extractedRoot = $found.FullName }
    }

    $bootstrapScript = Join-Path $extractedRoot "bootstrap.ps1"
    if (-not (Test-Path $bootstrapScript)) {
        throw "Lỗi: Không tìm thấy bootstrap.ps1 trong gói cài đặt."
    }

    Write-Host "==> Launching bootstrap..." -ForegroundColor Cyan
    & $bootstrapScript
}
finally {
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    if (Test-Path $zipFile) {
        try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($zipFile, 'OnlyErrorDialogs', 'SendToRecycleBin') } catch {}
    }
    if (Test-Path $tempBase) {
        try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($tempBase, 'OnlyErrorDialogs', 'SendToRecycleBin') } catch {}
    }
}
