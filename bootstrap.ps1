# bootstrap.ps1 - Bootstrap Claude Code environment on fresh machine
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipInstall,
    [string]$ClaudeDir = "$env:USERPROFILE\.claude",
    [string]$ClaudeJson = "$env:USERPROFILE\.claude.json"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Checking runtime dependencies..." -ForegroundColor Cyan
foreach ($tool in @("node", "npm", "git")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Missing '$tool' in PATH. Please install it first."
    }
}

$nodeVerRaw = (node -v 2>$null | Out-String).Trim()
try {
    $nodeVer = [version]($nodeVerRaw.TrimStart('v'))
} catch {
    throw "Không thể xác định version của Node.js: '$nodeVerRaw'"
}
if ($nodeVer -lt [version]"22.18.0") {
    throw "Yêu cầu Node.js >= 22.18.0. Phiên bản hiện tại: '$nodeVerRaw'."
}

if (-not $SkipInstall -and -not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Host "==> 'uv' not found. Installing uv..." -ForegroundColor Cyan
    if (-not $DryRun) {
        $installed = $false
        if (Get-Command "winget" -ErrorAction SilentlyContinue) {
            try { winget install --id=astral-sh.uv -e --silent --accept-source-agreements --accept-package-agreements; $installed = $true } catch {}
        }
        if (-not $installed) {
            try { irm https://astral.sh/uv/install.ps1 | iex; $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:Path" } catch { Write-Warning "Could not install uv." }
        }
    }
}
if (-not $SkipInstall) {
    Write-Host "==> Installing/updating mcp-atlassian globally via uv tool..." -ForegroundColor Cyan
    if (-not $DryRun -and (Get-Command "uv" -ErrorAction SilentlyContinue)) {
        try { uv tool install mcp-atlassian==0.23.1 --upgrade } catch { Write-Warning "Failed to install mcp-atlassian: $($_.Exception.Message)" }
    }
}

if (-not $SkipInstall -and -not (Get-Command "glab" -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing glab globally..." -ForegroundColor Cyan
    if (-not $DryRun -and (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        try {
            winget install -e --id GLab.GLab --silent --accept-source-agreements --accept-package-agreements | Out-Null
            if (Test-Path "$env:LOCALAPPDATA\Programs\glab") { $env:Path = "$env:LOCALAPPDATA\Programs\glab;$env:Path" }
        } catch {}
    }
}

if (-not $SkipInstall -and -not (Get-Command "memorix" -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing memorix globally..." -ForegroundColor Cyan
    if (-not $DryRun) { npm install -g memorix --silent }
}

if (-not $SkipInstall) {
    Write-Host "==> Registering memorix Claude Code plugin + hooks..." -ForegroundColor Cyan
    if (-not $DryRun) {
        try { memorix hooks install --agent claude --global } catch { Write-Warning "memorix hooks install failed: $($_.Exception.Message)" }
    }
}

if (-not $SkipInstall) {
    Write-Host "==> Installing gitnexus globally..." -ForegroundColor Cyan
    if (-not $DryRun) { npm install -g gitnexus --silent }
}
$gn = Get-Command "gitnexus" -ErrorAction SilentlyContinue
if (-not $gn) { throw "Lỗi: Không tìm thấy gitnexus." }

if (-not $SkipInstall) {
    Write-Host "==> Installing context7 globally..." -ForegroundColor Cyan
    if (-not $DryRun) { npm install -g @upstash/context7-mcp --silent }
}
$npmRoot2 = (npm root -g 2>$null).Trim()
if (-not $npmRoot2) { throw "Lỗi: Không tìm thấy npm root." }

function Load-Env {
    $EnvPath = Join-Path $PSScriptRoot ".env"
    if (Test-Path $EnvPath) {
        Get-Content $EnvPath | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#")) {
                $idx = $line.IndexOf("=")
                if ($idx -gt 0) {
                    $key = $line.Substring(0, $idx).Trim()
                    $val = $line.Substring($idx + 1).Trim().Trim('"', "'")
                    if ($key -and $val) { [Environment]::SetEnvironmentVariable($key, $val, "Process") }
                }
            }
        }
    }
}
Load-Env

function Get-EnvOrPrompt {
    param([string]$EnvName, [string]$Prompt, [string]$Default, [switch]$AllowEmpty)
    $val = [Environment]::GetEnvironmentVariable($EnvName, "Process")
    if (-not [string]::IsNullOrWhiteSpace($val)) { return $val }
    $hasDefault = $PSBoundParameters.ContainsKey('Default')
    while ($true) {
        $p = if ($hasDefault) { "$Prompt (Default: $Default)" } else { $Prompt }
        $in = Read-Host $p
        if (-not [string]::IsNullOrWhiteSpace($in)) { return $in.Trim() }
        if ($hasDefault) { return $Default }
        if ($AllowEmpty) { return "" }
        Write-Host "Error: '$EnvName' is required." -ForegroundColor Red
    }
}

$aiBaseUrl = Get-EnvOrPrompt -EnvName "AI_BASE_URL" -Prompt "AI Base URL" -Default "https://openrouter.ai/api/v1"
$aiKey     = Get-EnvOrPrompt -EnvName "AI_API_KEY" -Prompt "AI API Key"
$jiraUrl   = Get-EnvOrPrompt -EnvName "JIRA_URL" -Prompt "Jira URL" -Default "https://jira.cybertech.vn"
$jiraToken = Get-EnvOrPrompt -EnvName "JIRA_PERSONAL_TOKEN" -Prompt "Jira Personal Token" -Default "YOUR_JIRA_PERSONAL_TOKEN"
$confUrl   = Get-EnvOrPrompt -EnvName "CONFLUENCE_URL" -Prompt "Confluence URL" -Default "https://conf.cybertech.vn"
$confToken = Get-EnvOrPrompt -EnvName "CONFLUENCE_PERSONAL_TOKEN" -Prompt "Confluence Personal Token" -Default "YOUR_CONFLUENCE_PERSONAL_TOKEN"
$ctxKey    = Get-EnvOrPrompt -EnvName "CONTEXT7_API_KEY" -Prompt "Context7 API Key" -AllowEmpty
$gitlabHost = Get-EnvOrPrompt -EnvName "GITLAB_HOST" -Prompt "GitLab Host" -Default "10.30.1.17"
$gitlabToken = Get-EnvOrPrompt -EnvName "GITLAB_TOKEN" -Prompt "GitLab Personal Token" -AllowEmpty

if (-not [string]::IsNullOrWhiteSpace($gitlabToken) -and -not $DryRun) {
    Write-Host "==> Configuring GitLab authentication for host '$gitlabHost'..." -ForegroundColor Cyan
    $proto = if ($gitlabHost -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' -or $gitlabHost -match ':80') { "http" } else { "https" }
    $glabCmd = if (Get-Command "glab" -ErrorAction SilentlyContinue) { "glab" } elseif (Test-Path "$env:LOCALAPPDATA\Programs\glab\glab.exe") { "$env:LOCALAPPDATA\Programs\glab\glab.exe" } else { "glab" }
    try {
        & $glabCmd config set api_protocol $proto -g --host $gitlabHost 2>$null
        $tokenSec = $gitlabToken.Trim()
        & $glabCmd auth login --hostname $gitlabHost --token $tokenSec 2>$null
    } catch {}
}

if (-not $DryRun -and $ClaudeDir -eq "$env:USERPROFILE\.claude") {
    Write-Host "==> Setting global environment variables for Claude Code..." -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $aiBaseUrl, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $aiKey, "User")
}

Write-Host "==> Ensuring directory $ClaudeDir exists..." -ForegroundColor Cyan
if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null }

$cbSourceDir = Join-Path $PSScriptRoot "mcp-servers\cloakbrowser"
$cbTargetDir = "$env:USERPROFILE\mcp-servers\cloakbrowser"
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $cbTargetDir | Out-Null
    if (-not (Test-Path (Join-Path $cbTargetDir "package.json"))) {
        Copy-Item -Path "$cbSourceDir\*" -Destination $cbTargetDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
$cloakScript = (Join-Path $cbTargetDir "mcp-server-full.mjs").Replace('\', '\\')

$mcpJsonStr = @"
{
  "memorix": {
    "command": "npx",
    "args": ["-y", "memorix@latest", "serve", "--mode", "lite"]
  },
  "gitnexus": {
    "command": "cmd",
    "args": ["/c", "$($gn.Source.Replace('\', '\\'))", "mcp"]
  },
  "company-atlassian": {
    "command": "mcp-atlassian",
    "args": [],
    "env": {
      "JIRA_URL": "$jiraUrl",
      "JIRA_PERSONAL_TOKEN": "$jiraToken",
      "CONFLUENCE_URL": "$confUrl",
      "CONFLUENCE_PERSONAL_TOKEN": "$confToken",
      "TOOLSETS": "default"
    }
  },
  "context7": {
    "command": "node",
    "args": ["$((Join-Path $npmRoot2 '@upstash\context7-mcp\dist\index.js').Replace('\', '\\'))"],
    "env": { "CONTEXT7_API_KEY": "$ctxKey" }
  },
  "glab": {
    "command": "glab",
    "args": ["mcp", "serve"]
  },
  "cloakbrowser": {
    "command": "node",
    "args": ["$cloakScript"]
  }
}
"@
if (-not $ctxKey) {
    $mcpJsonStr = $mcpJsonStr -replace ',\s*"env":\s*\{\s*"CONTEXT7_API_KEY":\s*""\s*\}', ''
}

Write-Host "==> Injecting mcpServers into $ClaudeJson..." -ForegroundColor Cyan
if (-not $DryRun) {
    $parsedMcp = $mcpJsonStr | ConvertFrom-Json
    $existing = @{}
    if (Test-Path $ClaudeJson) {
        $existing = (Get-Content $ClaudeJson -Raw) | ConvertFrom-Json
    }
    if (-not $existing) { $existing = [PSCustomObject]@{} }
    $existing | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value $parsedMcp -Force
    $existing | ConvertTo-Json -Depth 10 | Set-Content -Path $ClaudeJson -Encoding UTF8
}

Write-Host "==> Copying static files and skills to $ClaudeDir..." -ForegroundColor Cyan
if (-not $DryRun) {
    $claudeMdPath = Join-Path $ClaudeDir "CLAUDE.md"
    $mdContent = ""
    foreach ($mdFile in @("SYSTEM.md", "AGENTS.md", "RULES.md")) {
        $srcPath = Join-Path $PSScriptRoot $mdFile
        if (Test-Path $srcPath) {
            $mdContent += (Get-Content -Path $srcPath -Raw) + "`n`n"
        }
    }
    Set-Content -Path $claudeMdPath -Value $mdContent -Encoding UTF8
    
    $srcSkills = Join-Path $PSScriptRoot "skills"
    $targetSkills = Join-Path $ClaudeDir "skills"
    if (Test-Path $srcSkills) {
        Copy-Item -Path $srcSkills -Destination $targetSkills -Recurse -Force
    }
}

Write-Host "`nBootstrap finished. Restart your terminal so ANTHROPIC_BASE_URL and ANTHROPIC_API_KEY apply globally." -ForegroundColor Green
