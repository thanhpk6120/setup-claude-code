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
        $p = $Prompt
        if ($hasDefault) { $p = "$Prompt (Default: $Default)" }
        $in = Read-Host $p
        if (-not [string]::IsNullOrWhiteSpace($in)) { return $in.Trim() }
        if ($hasDefault) { return $Default }
        if ($AllowEmpty) { return "" }
        Write-Host "Error: '$EnvName' is required." -ForegroundColor Red
    }
}

$aiBaseUrl = Get-EnvOrPrompt -EnvName "AI_BASE_URL" -Prompt "AI Base URL" -Default "http://localhost:20128/v1"
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
    $proto = "https"
    if ($gitlabHost -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' -or $gitlabHost -match ':80') { $proto = "http" }
    $glabCmd = "glab"
    if (Get-Command "glab" -ErrorAction SilentlyContinue) { $glabCmd = "glab" } elseif (Test-Path "$env:LOCALAPPDATA\Programs\glab\glab.exe") { $glabCmd = "$env:LOCALAPPDATA\Programs\glab\glab.exe" }
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
    [Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $aiKey, "User")
}

Write-Host "==> Ensuring directory $ClaudeDir exists..." -ForegroundColor Cyan
if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null }

function Get-CloakBrowserInstallDir {
    param([string]$EnvVarName = "CLOAKBROWSER_DIR")
    $envVal = [Environment]::GetEnvironmentVariable($EnvVarName, "Process")
    if (-not [string]::IsNullOrWhiteSpace($envVal)) { return $envVal.Trim() }

    $drives = @()
    try {
        $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 } | Sort-Object FreeSpace -Descending
    } catch {
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } | Sort-Object Free -Descending
    }
    if (-not $drives -or $drives.Count -eq 0) { return "$env:USERPROFILE\mcp-servers\cloakbrowser" }

    $defaultDrive = $drives | Where-Object { ($_.DeviceID -eq 'D:' -or $_.Name -eq 'D') } | Select-Object -First 1
    if (-not $defaultDrive) { $defaultDrive = $drives[0] }
    $defaultLetter = ""
    if ($defaultDrive.DeviceID) { $defaultLetter = $defaultDrive.DeviceID } else { $defaultLetter = "$($defaultDrive.Name):" }
    if ([Environment]::GetEnvironmentVariable("CI") -or -not [Environment]::UserInteractive) {
        return "$defaultLetter\mcp-servers\cloakbrowser"
    }

    Write-Host "`n==> Quet danh sach o dia (Local Drives) de cai dat CloakBrowser MCP:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $d = $drives[$i]
        $devId = ""
        if ($d.DeviceID) { $devId = $d.DeviceID } else { $devId = "$($d.Name):" }
        $volName = ""
        if ($d.VolumeName) { $volName = " ($($d.VolumeName))" }
        $freeGB = 0
        $freeVal = $d.Free
        if ($d.FreeSpace) { $freeVal = $d.FreeSpace }
        $freeGB = [math]::Round(($freeVal / 1GB), 2)
        $sizeGB = "N/A"
        if ($d.Size) { $sizeGB = [math]::Round(($d.Size / 1GB), 2) }
        Write-Host "  [$($i+1)] O $devId$volName | Trong: $freeGB GB / $sizeGB GB"
    }

    $promptMsg = "Chon so thu tu o dia muon luu CloakBrowser (mac dinh o $defaultLetter)"
    try {
        $inputVal = Read-Host $promptMsg
        if (-not [string]::IsNullOrWhiteSpace($inputVal)) {
            $choice = $inputVal.Trim()
            $idx = 0
            if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $drives.Count) {
                $chosen = $drives[$idx - 1]
                $chosenLetter = ""
                if ($chosen.DeviceID) { $chosenLetter = $chosen.DeviceID } else { $chosenLetter = "$($chosen.Name):" }
                return "$chosenLetter\mcp-servers\cloakbrowser"
            }
        }
    } catch {}
    return "$defaultLetter\mcp-servers\cloakbrowser"
}

function Setup-CloakBrowser {
    param([string]$TargetDir, [string]$SourceDir, [switch]$DryRun, [switch]$SkipInstall)
    Write-Host "==> Cau hinh CloakBrowser tai: $TargetDir" -ForegroundColor Cyan
    if (-not (Test-Path $TargetDir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
    }

    $mainScript = Join-Path $TargetDir "mcp-server-full.mjs"
    $pkgJson = Join-Path $TargetDir "package.json"
    if ((Test-Path $mainScript) -and (Test-Path $pkgJson)) {
        Write-Host "  -> CloakBrowser da ton tai day du file ma nguon. Giu nguyen du lieu & profile cu (khong ghi de)." -ForegroundColor Green
    } else {
        Write-Host "  -> Copy ma nguon CloakBrowser sang $TargetDir..." -ForegroundColor Green
        if (-not $DryRun -and (Test-Path $SourceDir)) {
            Copy-Item -Path "$SourceDir\*" -Destination $TargetDir -Recurse -Force
        }
    }

    $nodeModules = Join-Path $TargetDir "node_modules"
    if (-not $SkipInstall -and -not (Test-Path $nodeModules)) {
        Write-Host "  -> Dang chay 'npm install' cho CloakBrowser..." -ForegroundColor Cyan
        if (-not $DryRun) {
            Push-Location $TargetDir
            try { npm install --omit=dev --silent } catch { Write-Warning "npm install cho CloakBrowser gap loi: $($_.Exception.Message)" } finally { Pop-Location }
        }
    }
    return $mainScript
}

$cbSourceDir = Join-Path $PSScriptRoot "mcp-servers\cloakbrowser"
$cbTargetDir = Get-CloakBrowserInstallDir
$cloakScriptPath = Setup-CloakBrowser -TargetDir $cbTargetDir -SourceDir $cbSourceDir -DryRun:$DryRun -SkipInstall:$SkipInstall
$cloakScript = ($cloakScriptPath).Replace('\', '\\')

$mcpJsonStr = @"
{
  "memorix": {
    "command": "memorix",
    "args": ["serve", "--mode", "lite"]
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
    $jsonContent = $existing | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($ClaudeJson, $jsonContent, [System.Text.UTF8Encoding]::new($false))
}

$userProfileFwd = $env:USERPROFILE.Replace('\', '/')
$targetTrashGuard = Join-Path $env:USERPROFILE ".trash-guard"
if (-not $DryRun) {
    if (-not (Test-Path $targetTrashGuard)) {
        New-Item -ItemType Directory -Path $targetTrashGuard -Force | Out-Null
    }
    $srcTrashGuard = Join-Path $PSScriptRoot "trash-guard"
    if (Test-Path $srcTrashGuard) {
        Copy-Item -Path "$srcTrashGuard\*" -Destination $targetTrashGuard -Force -Recurse
    }

    $srcHud = Join-Path $PSScriptRoot "hud"
    $targetHudDir = Join-Path $ClaudeDir "hud"
    if (Test-Path $srcHud) {
        if (-not (Test-Path $targetHudDir)) {
            New-Item -ItemType Directory -Path $targetHudDir -Force | Out-Null
        }
        Copy-Item -Path "$srcHud\*" -Destination $targetHudDir -Force -Recurse
    }
}

$hudSrcFile = Join-Path $PSScriptRoot "hud/hud.mjs"
$hudDestFile = Join-Path $ClaudeDir "hud/hud.mjs"
    $hudEffective = $hudDestFile
    if ($env:HUD_PATH) { $hudEffective = $env:HUD_PATH }
$hasHud = (Test-Path $hudEffective) -or ((-not $env:HUD_PATH) -and (Test-Path $hudSrcFile))

$claudeDirFwd = $ClaudeDir.Replace('\','/')
    $hudCmdJson = "$claudeDirFwd/hud/hud.mjs"
    if ($env:HUD_PATH) { $hudCmdJson = $env:HUD_PATH.Replace('\','/') }

 $hudStatusLine = ""
 if ($hasHud) {
     $hudStatusLine = ",`n  `"statusLine`": {`n    `"type`": `"command`",`n    `"command`": `"node $hudCmdJson`"`n  }"
 }

    $trashGuardCmd = Join-Path $env:USERPROFILE ".trash-guard/claude-pre-tool.cmd"
    if ($env:TRASH_GUARD_HOOK_PATH) { $trashGuardCmd = $env:TRASH_GUARD_HOOK_PATH }
$trashGuardPreToolUse = ""
if (Test-Path $trashGuardCmd) {
$trashGuardPreToolUse = @"
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.trash-guard/claude-pre-tool.cmd",
            "timeout": 15
          }
        ]
      },
      {
        "matcher": "PowerShell",
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.trash-guard/claude-pre-tool.cmd",
            "timeout": 15
          }
        ]
      }
    ],

"@
}

    $orcaHookPath = Join-Path $env:USERPROFILE ".orca/agent-hooks/claude-hook.cmd"
    if ($env:ORCA_HOOK_PATH) { $orcaHookPath = $env:ORCA_HOOK_PATH }
$hasOrca = Test-Path $orcaHookPath

$orcaSessionStart = ""
$orcaPostToolUse = ""
$orcaUserPromptSubmit = ""
$orcaStop = ""
$orcaStopFailure = ""
$orcaSubagentStart = ""
$orcaSubagentStop = ""
$orcaTeammateIdle = ""
$orcaPostToolUseFailure = ""
$orcaPermissionRequest = ""

if ($hasOrca) {
$orcaSessionStart = @"
,
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
"@

$orcaPostToolUse = @"
,
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
"@

$orcaUserPromptSubmit = @"
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
    ],

"@

$orcaStop = @"
,
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
"@

$orcaStopFailure = @"
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
    ],

"@

$orcaSubagentStart = @"
    "SubagentStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
    ],

"@

$orcaSubagentStop = @"
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
    ],

"@

$orcaTeammateIdle = @"
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
    ],

"@

$orcaPostToolUseFailure = @"
    "PostToolUseFailure": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
    ],

"@

$orcaPermissionRequest = @"
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd",
            "timeout": 60
          }
        ]
      }
    ],

"@
}
$settingsTemplate = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "$aiBaseUrl",
    "ANTHROPIC_AUTH_TOKEN": "$aiKey",
    "ANTHROPIC_DEFAULT_FABLE_MODEL": "claude-fable-5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001",
    "ANTHROPIC_MODEL": "claude-sonnet-5",
    "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet[1m]",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_DANGEROUSLY_SKIP_PERMISSIONS": "1",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1",
    "CLAUDE_CODE_NO_FLICKER": "1",
    "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1",
    "MCP_TIMEOUT": "120000",
    "MCP_TOOL_TIMEOUT": "120000"
  },
  "permissions": {
    "allow": [],
    "deny": [],
    "defaultMode": "bypassPermissions"
  },
  "model": "sonnet[1m]",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "memorix.cmd hook",
            "timeout": 60
          }
        ]
      }$orcaSessionStart
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "memorix.cmd hook",
            "timeout": 60
          }
        ]
      }$orcaPostToolUse
    ],
$orcaUserPromptSubmit    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "memorix.cmd hook",
            "timeout": 60
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "memorix.cmd hook",
            "timeout": 60
          }
        ]
      }$orcaStop
    ],
$orcaStopFailure$orcaSubagentStart$orcaSubagentStop$orcaTeammateIdle$trashGuardPreToolUse
$orcaPostToolUseFailure$orcaPermissionRequest    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "memorix.cmd hook",
            "timeout": 60
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "memorix.cmd hook",
            "timeout": 60
          }
        ]
      }
    ]
  },
  "enableWorkflows": true$hudStatusLine,
  "autoUpdatesChannel": "latest",
  "skipDangerousModePermissionPrompt": true,
  "theme": "dark",
  "version": 1,
  "autoCompactEnabled": false
}
"@

Write-Host "==> Writing settings.json to $ClaudeDir..." -ForegroundColor Cyan
if (-not $DryRun) {
    $settingsPath = Join-Path $ClaudeDir "settings.json"
    [System.IO.File]::WriteAllText($settingsPath, $settingsTemplate, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "==> Copying static files and skills to $ClaudeDir..." -ForegroundColor Cyan
if (-not $DryRun) {
    $claudeMdPath = Join-Path $ClaudeDir "CLAUDE.md"
    $srcClaude = Join-Path $PSScriptRoot "CLAUDE.md"
    if (Test-Path $srcClaude) {
        Copy-Item -Path $srcClaude -Destination $claudeMdPath -Force
    }
    
    $srcSkills = Join-Path $PSScriptRoot "skills"
    $targetSkills = Join-Path $ClaudeDir "skills"
    if (Test-Path $srcSkills) {
        Copy-Item -Path $srcSkills -Destination $targetSkills -Recurse -Force
    }
}

Write-Host "`nBootstrap finished. Restart your terminal so ANTHROPIC_BASE_URL and ANTHROPIC_API_KEY apply globally." -ForegroundColor Green
