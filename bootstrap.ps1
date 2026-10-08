# bootstrap.ps1 - Bootstrap Claude Code environment on fresh machine
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$Force,
    [switch]$OverwriteAll,
    [switch]$EnableMemorix,
    [switch]$DisableMemorix,
    [string]$ClaudeDir = "$env:USERPROFILE\.claude",
    [string]$ClaudeJson = "$env:USERPROFILE\.claude.json"
)

$ErrorActionPreference = "Stop"

# Thư viện VisualBasic hỗ trợ chuyển file/thư mục vào Recycle Bin
Add-Type -AssemblyName Microsoft.VisualBasic

function Move-ToRecycleBinDirectory([string]$Path) {
    if (Test-Path $Path) {
        try {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
            Write-Host "  [Thùng rác] Đã chuyển thư mục vào Recycle Bin: $Path" -ForegroundColor DarkGray
        } catch {
            Write-Warning "Không thể chuyển thư mục vào Recycle Bin: $Path ($($_.Exception.Message))"
        }
    }
}

function Move-ToRecycleBinFile([string]$Path) {
    if (Test-Path $Path) {
        try {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
            Write-Host "  [Thùng rác] Đã chuyển file vào Recycle Bin: $Path" -ForegroundColor DarkGray
        } catch {
            Write-Warning "Không thể chuyển file vào Recycle Bin: $Path ($($_.Exception.Message))"
        }
    }
}

# Xác định cờ $EnableMemorix
$existingMemorix = Get-Command "memorix" -ErrorAction SilentlyContinue
if (-not $PSBoundParameters.ContainsKey('EnableMemorix') -and -not $PSBoundParameters.ContainsKey('DisableMemorix')) {
    if ($env:ENABLE_MEMORIX) {
        $EnableMemorix = ($env:ENABLE_MEMORIX -eq '1' -or $env:ENABLE_MEMORIX -eq 'true')
    } elseif ($existingMemorix) {
        Write-Host "==> Đã phát hiện Memorix trên máy (tại: $($existingMemorix.Source)). Tự động kích hoạt và cập nhật..." -ForegroundColor Green
        $EnableMemorix = $true
    } elseif ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        $memorixChoice = Read-Host "Bạn có muốn cài đặt Memorix (MCP & Session Memory) không? [y/N]"
        $EnableMemorix = if (-not [string]::IsNullOrWhiteSpace($memorixChoice) -and $memorixChoice.Trim().ToLower() -eq 'y') { $true } else { $false }
    } else {
        if ($env:AI_BASE_URL -eq "https://test.local") { $EnableMemorix = $true } else { $EnableMemorix = $false }
    }
} elseif ($DisableMemorix.IsPresent) {
    $EnableMemorix = $false
} else {
    $EnableMemorix = $EnableMemorix.IsPresent
}

$isForce = $Force.IsPresent -or $OverwriteAll.IsPresent

# Đọc cấu hình từ .env nếu tồn tại
$envMap = @{}
$dotEnvPath = Join-Path $PSScriptRoot ".env"
if (Test-Path $dotEnvPath) {
    Write-Host "==> Đọc cấu hình từ file .env ($dotEnvPath)..." -ForegroundColor Cyan
    Get-Content $dotEnvPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line -split "=", 2
            if ($parts.Count -eq 2) {
                $k = $parts[0].Trim()
                $v = $parts[1].Trim().Trim('"').Trim("'")
                $envMap[$k] = $v
            }
        }
    }
}

function Get-EnvOrPrompt {
    param(
        [string]$EnvName,
        [string]$Prompt,
        [string]$Default = "",
        [switch]$Required,
        [switch]$AllowEmpty
    )
    $envVal = [System.Environment]::GetEnvironmentVariable($EnvName)
    if (-not [string]::IsNullOrWhiteSpace($envVal)) { return $envVal }
    if ($envMap.ContainsKey($EnvName) -and -not [string]::IsNullOrWhiteSpace($envMap[$EnvName])) {
        return $envMap[$EnvName]
    }
    if ($Default -and (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected)) {
        return $Default
    }
    if ($AllowEmpty -and (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected)) {
        return ""
    }
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        $promptStr = if ($Default) { "$Prompt (mặc định: $Default)" } else { $Prompt }
        while ($true) {
            $inputVal = Read-Host $promptStr
            if ([string]::IsNullOrWhiteSpace($inputVal)) {
                if ($Default) { return $Default }
                if ($AllowEmpty) { return "" }
                if ($Required) {
                    Write-Host "Giá trị này là bắt buộc, vui lòng nhập lại!" -ForegroundColor Red
                    continue
                }
            } else {
                return $inputVal.Trim()
            }
        }
    }
    return $Default
}

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
    $toolsList = "gitnexus, context7"
    if ($EnableMemorix) { $toolsList = "memorix, gitnexus, context7" }
    throw "Yêu cầu Node.js >= 22.18.0 (do $toolsList yêu cầu Node.js mới). Phiên bản hiện tại: '$nodeVerRaw'. Vui lòng nâng cấp Node.js."
}

# Cài đặt uv
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

# Cài đặt mcp-atlassian (kiểm tra phiên bản trước để tránh lỗi khóa file Windows)
if (-not $SkipInstall) {
    $targetAtlassianVer = "0.23.1"
    $atlassianCmd = Get-Command "mcp-atlassian" -ErrorAction SilentlyContinue
    $needAtlassianInstall = $true

    if ($atlassianCmd) {
        try {
            $currentVer = (& mcp-atlassian --version 2>&1 | Out-String).Trim()
            if ($currentVer -match $targetAtlassianVer) {
                Write-Host "  -> mcp-atlassian==$targetAtlassianVer đã được cài đặt và đúng phiên bản. Bỏ qua cài đặt lại để tránh lỗi khóa file Windows (Access is denied / os error 5)." -ForegroundColor Green
                $needAtlassianInstall = $false
            }
        } catch {}
    }

    if ($needAtlassianInstall) {
        Write-Host "==> Đang cài đặt mcp-atlassian==$targetAtlassianVer qua uv tool..." -ForegroundColor Cyan
        if (-not $DryRun -and (Get-Command "uv" -ErrorAction SilentlyContinue)) {
            try {
                uv tool install "mcp-atlassian==$targetAtlassianVer" --upgrade
            } catch {
                if ($_.Exception.Message -match "os error 5" -or $_.Exception.Message -match "Access is denied") {
                    Write-Warning "Không thể ghi đè mcp-atlassian do tiến trình đang chạy ngầm trong hệ thống (Windows File Lock). Bản hiện tại vẫn sẽ được tiếp tục sử dụng."
                } else {
                    Write-Warning "Cài đặt mcp-atlassian gặp lỗi: $($_.Exception.Message)"
                }
            }
        }
    }
}

# Cài đặt glab
if (-not $SkipInstall -and -not (Get-Command "glab" -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing glab globally..." -ForegroundColor Cyan
    if (-not $DryRun -and (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        try {
            winget install -e --id GLab.GLab --silent --accept-source-agreements --accept-package-agreements | Out-Null
            if (Test-Path "$env:LOCALAPPDATA\Programs\glab") { $env:Path = "$env:LOCALAPPDATA\Programs\glab;$env:Path" }
        } catch {}
    }
}

# Cài đặt / cập nhật memorix (khi $EnableMemorix = $true)
if ($EnableMemorix) {
    if (-not $SkipInstall) {
        Write-Host "==> Đang cài đặt / cập nhật Memorix lên phiên bản mới nhất (npm install -g memorix)..." -ForegroundColor Cyan
        if (-not $DryRun) {
            try {
                npm install -g memorix
            } catch {
                Write-Warning "Cài đặt/cập nhật Memorix gặp lỗi: $($_.Exception.Message)"
            }
        }
    }
    if (-not $SkipInstall) {
        Write-Host "==> Registering memorix Claude Code plugin + hooks..." -ForegroundColor Cyan
        if (-not $DryRun) {
            try { memorix hooks install --agent claude --global } catch { Write-Warning "memorix hooks install failed: $($_.Exception.Message)" }
        }
    }
}

# Cài đặt gitnexus
if (-not $SkipInstall) {
    Write-Host "==> Installing gitnexus globally..." -ForegroundColor Cyan
    if (-not $DryRun) { npm install -g gitnexus --silent }
}
$gn = Get-Command "gitnexus" -ErrorAction SilentlyContinue
if (-not $gn) { throw "Lỗi: Không tìm thấy gitnexus." }

# Cài đặt context7
if (-not $SkipInstall) {
    Write-Host "==> Installing context7 globally..." -ForegroundColor Cyan
    if (-not $DryRun) { npm install -g @upstash/context7-mcp --silent }
}

$npmRoot2 = ""
try {
    $npmRoot2 = (npm root -g 2>$null) | Out-String
    $npmRoot2 = $npmRoot2.Trim()
} catch {}

if ($npmRoot2) {
    $ctxP2 = Join-Path $npmRoot2 "@upstash\context7-mcp\dist\index.js"
    if (Test-Path $ctxP2) {
        $absCtx2 = ($ctxP2).Replace('\', '\\')
    } else {
        throw "Lỗi: Không tìm thấy file dist\index.js của context7. Dừng cài đặt."
    }
} else {
    throw "Lỗi: Không tìm thấy thư mục npm root -g để lấy đường dẫn context7. Dừng cài đặt."
}

# Cấu hình CloakBrowser
function Get-CloakBrowserInstallDir {
    if ($env:CLOAKBROWSER_DIR) { return $env:CLOAKBROWSER_DIR }
    $defaultLetter = "D:"
    if (-not (Test-Path "D:\")) { $defaultLetter = "C:" }
    $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | Sort-Object DeviceID)
    if ($drives.Count -eq 0) {
        try { $drives = @(Get-PSDrive -PSProvider 'FileSystem' | Where-Object { $_.Free -gt 0 } | Sort-Object Name) } catch {}
    }
    if ($drives.Count -le 1) { return "$defaultLetter\mcp-servers\cloakbrowser" }
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) { return "$defaultLetter\mcp-servers\cloakbrowser" }

    Write-Host ""
    Write-Host "==> Phat hien he thong co nhieu o dia:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $d = $drives[$i]
        $devId = if ($d.DeviceID) { $d.DeviceID } else { "$($d.Name):" }
        $volName = if ($d.VolumeName) { " ($($d.VolumeName))" } else { "" }
        $freeVal = if ($d.FreeSpace) { $d.FreeSpace } else { $d.Free }
        $freeGB = [math]::Round(($freeVal / 1GB), 2)
        $sizeGB = if ($d.Size) { [math]::Round(($d.Size / 1GB), 2) } else { "N/A" }
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
                $chosenLetter = if ($chosen.DeviceID) { $chosen.DeviceID } else { "$($chosen.Name):" }
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
        if (Test-Path $SourceDir) {
            Write-Host "  -> Sao chep ma nguon CloakBrowser tu bo cai vao $TargetDir..." -ForegroundColor DarkGray
            if (-not $DryRun) { Copy-Item -Path "$SourceDir\*" -Destination $TargetDir -Recurse -Force }
        } else {
            Write-Warning "Khong tim thay thu muc ma nguon CloakBrowser tai: $SourceDir"
        }
    }

    if (-not $SkipInstall -and -not $DryRun) {
        $needsNpmInstall = $false
        $nodeModulesDir = Join-Path $TargetDir "node_modules"
        if (-not (Test-Path $nodeModulesDir)) {
            $needsNpmInstall = $true
        } else {
            foreach ($dep in @("@modelcontextprotocol\sdk", "playwright", "dotenv")) {
                if (-not (Test-Path (Join-Path $nodeModulesDir $dep))) {
                    $needsNpmInstall = $true
                    break
                }
            }
        }
        if ($needsNpmInstall) {
            Write-Host "  -> Dang cai dat dependencies cho CloakBrowser (npm install --silent)..." -ForegroundColor DarkGray
            Push-Location $TargetDir
            try { npm install --silent } catch { Write-Warning "npm install tai CloakBrowser gap loi: $($_.Exception.Message)" }
            finally { Pop-Location }
        }
    }
    return $mainScript
}

$cbSourceDir = Join-Path $PSScriptRoot "mcp-servers\cloakbrowser"
$cbTargetDir = Get-CloakBrowserInstallDir
$cloakScriptPath = Setup-CloakBrowser -TargetDir $cbTargetDir -SourceDir $cbSourceDir -DryRun:$DryRun -SkipInstall:$SkipInstall
$cloakScript = ($cloakScriptPath).Replace('\', '\\')

# Thu thập cấu hình
$aiBaseUrl = Get-EnvOrPrompt -EnvName "AI_BASE_URL" -Prompt "AI Base URL" -Default "http://localhost:20128/v1"
$aiKey = Get-EnvOrPrompt -EnvName "AI_API_KEY" -Prompt "AI API Key" -Required
$jiraUrl = Get-EnvOrPrompt -EnvName "JIRA_URL" -Prompt "Jira URL" -AllowEmpty
$jiraToken = Get-EnvOrPrompt -EnvName "JIRA_PERSONAL_TOKEN" -Prompt "Jira Personal Token" -AllowEmpty
$confUrl = Get-EnvOrPrompt -EnvName "CONFLUENCE_URL" -Prompt "Confluence URL" -AllowEmpty
$confToken = Get-EnvOrPrompt -EnvName "CONFLUENCE_PERSONAL_TOKEN" -Prompt "Confluence Personal Token" -AllowEmpty
$ctxKey = Get-EnvOrPrompt -EnvName "CONTEXT7_API_KEY" -Prompt "Context7 API Key" -AllowEmpty
$gitlabHost = Get-EnvOrPrompt -EnvName "GITLAB_HOST" -Prompt "GitLab Host" -Default "10.30.1.17"
$gitlabToken = Get-EnvOrPrompt -EnvName "GITLAB_TOKEN" -Prompt "GitLab Personal Token" -AllowEmpty

# Xác thực glab nếu có token
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
        Write-Host "  -> Logged in to GitLab ($gitlabHost) successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Could not configure glab auth automatically: $($_.Exception.Message)"
    }
}

# Chuẩn bị đường dẫn gitnexus
$escapedGitnexus = ($gn.Source).Replace('\', '\\')

# Xử lý claude.json (hoặc mcp.json)
$templatesDir = Join-Path $PSScriptRoot "templates"
$claudeTemplatePath = Join-Path $templatesDir "claude.json"
if (-not (Test-Path $claudeTemplatePath)) { $claudeTemplatePath = Join-Path $templatesDir "mcp.json" }

if (Test-Path $claudeTemplatePath) {
    $mcpRaw = Get-Content -Path $claudeTemplatePath -Raw -Encoding UTF8
    $mcpJsonStr = $mcpRaw `
        -replace '__GITNEXUS_PATH__', $escapedGitnexus `
        -replace '__JIRA_URL__', $jiraUrl `
        -replace '__JIRA_PERSONAL_TOKEN__', $jiraToken `
        -replace '__CONFLUENCE_URL__', $confUrl `
        -replace '__CONFLUENCE_PERSONAL_TOKEN__', $confToken `
        -replace '__CONTEXT7_PATH__', $absCtx2 `
        -replace '__CONTEXT7_API_KEY__', $ctxKey `
        -replace '__CLOAKBROWSER_SCRIPT__', $cloakScript
} else {
    # Fallback mcp JSON string
    $mcpJsonStr = @"
{
  "mcpServers": {
    "gitnexus": {
      "command": "cmd",
      "args": ["/c", "$escapedGitnexus", "mcp"]
    },
    "company-atlassian": {
      "command": "uvx",
      "args": ["mcp-atlassian==0.23.1"],
      "env": {
        "JIRA_URL": "$jiraUrl",
        "JIRA_PERSONAL_TOKEN": "$jiraToken",
        "CONFLUENCE_URL": "$confUrl",
        "CONFLUENCE_PERSONAL_TOKEN": "$confToken"
      }
    },
    "context7": {
      "command": "node",
      "args": ["$absCtx2"],
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
}
"@
}

$mcpObj = $mcpJsonStr | ConvertFrom-Json
if (-not $mcpObj.mcpServers) {
    $mcpObj | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value ([PSCustomObject]@{}) -Force
}

# Xử lý server memorix trong mcpServers
if ($EnableMemorix) {
    $memorixMcp = [PSCustomObject]@{
        command = "memorix"
        args = @("mcp")
    }
    $mcpObj.mcpServers | Add-Member -MemberType NoteProperty -Name 'memorix' -Value $memorixMcp -Force
} else {
    if ($mcpObj.mcpServers.PSObject.Properties['memorix']) {
        $mcpObj.mcpServers.PSObject.Properties.Remove('memorix')
    }
}

# Ghi / Merge cấu hình vào $ClaudeJson
Write-Host "==> Xử lý cấu hình $ClaudeJson..." -ForegroundColor Cyan
if (Test-Path $ClaudeJson) {
    $bakJsonPath = "$ClaudeJson.bak"
    if ($isForce) {
        Write-Host "  -> File '$ClaudeJson' đã tồn tại. [-Force / -OverwriteAll] Tự động sao lưu và ghi đè." -ForegroundColor Yellow
        if (-not $DryRun) {
            Copy-Item -Path $ClaudeJson -Destination $bakJsonPath -Force
            Write-Host "     Đã sao lưu sang $bakJsonPath" -ForegroundColor DarkGray
            $existing = (Get-Content $ClaudeJson -Raw -Encoding UTF8) | ConvertFrom-Json
            if (-not $existing) { $existing = [PSCustomObject]@{} }
            $existing | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value $mcpObj.mcpServers -Force
            $outJson = $existing | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($ClaudeJson, $outJson, [System.Text.UTF8Encoding]::new($false))
        }
    } else {
        $choice = ""
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $choice = Read-Host "[?] File '$ClaudeJson' đã tồn tại. Bạn có muốn [O]verwrite (ghi đè), [M]erge (hợp nhất cấu hình cũ và mới), hay [S]kip (bỏ qua)? [O/M/s]"
            $choice = if ($choice) { $choice.Trim() } else { "" }
        } else {
            $choice = "M"
        }

        if ($choice -match '^[mM]$' -or ($choice -eq "" -and (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected))) {
            Write-Host "  -> Đang hợp nhất cấu hình MCP vào $ClaudeJson (sao lưu sang $bakJsonPath)..." -ForegroundColor Cyan
            if (-not $DryRun) {
                Copy-Item -Path $ClaudeJson -Destination $bakJsonPath -Force
                Write-Host "     Đã sao lưu sang $bakJsonPath" -ForegroundColor DarkGray
                try {
                    $existing = (Get-Content $ClaudeJson -Raw -Encoding UTF8) | ConvertFrom-Json
                    if (-not $existing) { $existing = [PSCustomObject]@{} }
                    if (-not $existing.PSObject.Properties['mcpServers']) {
                        $existing | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value ([PSCustomObject]@{}) -Force
                    }
                    foreach ($prop in $mcpObj.mcpServers.PSObject.Properties) {
                        $existing.mcpServers | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
                    }
                    if (-not $EnableMemorix -and $existing.mcpServers.PSObject.Properties['memorix']) {
                        $existing.mcpServers.PSObject.Properties.Remove('memorix')
                    }
                    $outJson = $existing | ConvertTo-Json -Depth 10
                    [System.IO.File]::WriteAllText($ClaudeJson, $outJson, [System.Text.UTF8Encoding]::new($false))
                    Write-Host "     Hợp nhất mcpServers thành công." -ForegroundColor Green
                } catch {
                    Write-Warning "Lỗi khi hợp nhất cấu hình ${ClaudeJson}: $($_.Exception.Message)"
                }
            }
        } elseif ($choice -match '^[oO]$') {
            Write-Host "  -> Ghi đè mcpServers trong $ClaudeJson (sao lưu sang $bakJsonPath)..." -ForegroundColor Green
            if (-not $DryRun) {
                Copy-Item -Path $ClaudeJson -Destination $bakJsonPath -Force
                Write-Host "     Đã sao lưu sang $bakJsonPath" -ForegroundColor DarkGray
                $existing = (Get-Content $ClaudeJson -Raw -Encoding UTF8) | ConvertFrom-Json
                if (-not $existing) { $existing = [PSCustomObject]@{} }
                $existing | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value $mcpObj.mcpServers -Force
                $outJson = $existing | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($ClaudeJson, $outJson, [System.Text.UTF8Encoding]::new($false))
            }
        } else {
            Write-Host "  -> Bỏ qua $ClaudeJson (giữ nguyên file hiện tại)." -ForegroundColor Yellow
        }
    }
} else {
    if (-not $DryRun) {
        $rootObj = [PSCustomObject]@{
            mcpServers = $mcpObj.mcpServers
        }
        $outJson = $rootObj | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($ClaudeJson, $outJson, [System.Text.UTF8Encoding]::new($false))
    }
}

# Đảm bảo các thư mục hỗ trợ
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
    # Dọn dẹp tuyệt đối PowerShell Profile: Đảm bảo terminal của người dùng sạch sẽ 100%
    $profileCandidates = @(
        "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
        "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
        "$env:USERPROFILE\Documents\PowerShell\profile.ps1",
        "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1"
    )
    foreach ($profPath in $profileCandidates) {
        if (Test-Path $profPath) {
            $profContent = Get-Content -Path $profPath -Raw -Encoding UTF8
            if ($profContent -match "trash-guard") {
                $cleanedProf = ($profContent -split "`r?`n" | Where-Object { $_ -notmatch "trash-guard" }) -join "`r`n"
                [System.IO.File]::WriteAllText($profPath, $cleanedProf.Trim() + "`r`n", [System.Text.UTF8Encoding]::new($false))
                Write-Host "  -> Đã gỡ bỏ hook trash-guard khỏi PowerShell Profile ($profPath) để giữ terminal sạch sẽ 100%." -ForegroundColor Green
            }
        }
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
$hasTrashGuard = Test-Path $trashGuardCmd

$orcaHookPath = Join-Path $env:USERPROFILE ".orca/agent-hooks/claude-hook.cmd"
if ($env:ORCA_HOOK_PATH) { $orcaHookPath = $env:ORCA_HOOK_PATH }
$hasOrca = Test-Path $orcaHookPath

# Xây dựng hooks cho settings.json
$hooksObj = [ordered]@{}

# SessionStart
$sessionStartHooks = [System.Collections.ArrayList]@()
if ($EnableMemorix) {
    $sessionStartHooks.Add([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "memorix.cmd hook"
            timeout = 60
        })
    }) | Out-Null
}
if ($hasOrca) {
    $sessionStartHooks.Add([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    }) | Out-Null
}
if ($sessionStartHooks.Count -gt 0) {
    $hooksObj["SessionStart"] = $sessionStartHooks
}

# PreToolUse
$preToolHooks = [System.Collections.ArrayList]@()
if ($hasTrashGuard) {
    $preToolHooks.Add([ordered]@{
        matcher = "Bash"
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.trash-guard/claude-pre-tool.cmd"
            timeout = 15
        })
    }) | Out-Null
    $preToolHooks.Add([ordered]@{
        matcher = "PowerShell"
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.trash-guard/claude-pre-tool.cmd"
            timeout = 15
        })
    }) | Out-Null
}
if ($preToolHooks.Count -gt 0) {
    $hooksObj["PreToolUse"] = $preToolHooks
}

# PostToolUse
$postToolHooks = [System.Collections.ArrayList]@()
if ($EnableMemorix) {
    $postToolHooks.Add([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "memorix.cmd hook"
            timeout = 60
        })
    }) | Out-Null
}
if ($hasOrca) {
    $postToolHooks.Add([ordered]@{
        matcher = "*"
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    }) | Out-Null
}
if ($postToolHooks.Count -gt 0) {
    $hooksObj["PostToolUse"] = $postToolHooks
}

if ($EnableMemorix) {
    $hooksObj["PreCompact"] = @(
        [ordered]@{
            hooks = @([ordered]@{
                type = "command"
                command = "memorix.cmd hook"
                timeout = 60
            })
        }
    )
    $hooksObj["PostCompact"] = @(
        [ordered]@{
            hooks = @([ordered]@{
                type = "command"
                command = "memorix.cmd hook"
                timeout = 60
            })
        }
    )
}

# Stop
$stopHooks = [System.Collections.ArrayList]@()
if ($EnableMemorix) {
    $stopHooks.Add([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "memorix.cmd hook"
            timeout = 60
        })
    }) | Out-Null
}
if ($hasOrca) {
    $stopHooks.Add([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    }) | Out-Null
}
if ($stopHooks.Count -gt 0) {
    $hooksObj["Stop"] = $stopHooks
}

# SessionEnd
$sessionEndHooks = [System.Collections.ArrayList]@()
if ($EnableMemorix) {
    $sessionEndHooks.Add([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "memorix.cmd hook"
            timeout = 60
        })
    }) | Out-Null
}
if ($hasOrca) {
    $sessionEndHooks.Add([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    }) | Out-Null
}
if ($sessionEndHooks.Count -gt 0) {
    $hooksObj["SessionEnd"] = $sessionEndHooks
}

# Orca optional lifecycle hooks
if ($hasOrca) {
    $hooksObj["UserPromptSubmit"] = @([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    })
    $hooksObj["StopFailure"] = @([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    })
    $hooksObj["SubagentStart"] = @([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    })
    $hooksObj["SubagentStop"] = @([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    })
    $hooksObj["TeammateIdle"] = @([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    })
    $hooksObj["PostToolUseFailure"] = @([ordered]@{
        matcher = "*"
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    })
    $hooksObj["PermissionRequest"] = @([ordered]@{
        hooks = @([ordered]@{
            type = "command"
            command = "$userProfileFwd/.orca/agent-hooks/claude-hook.cmd"
            timeout = 60
        })
    })
}

# Cấu hình settings.json
$settingsTemplatePath = Join-Path $templatesDir "settings.json"
$targetSettingsPath = Join-Path $ClaudeDir "settings.json"

if (-not (Test-Path $ClaudeDir)) {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null }
}

$settingsObj = [ordered]@{
    env = [ordered]@{
        ANTHROPIC_BASE_URL = $aiBaseUrl
        ANTHROPIC_AUTH_TOKEN = $aiKey
        ANTHROPIC_DEFAULT_FABLE_MODEL = "claude-fable-5"
        ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-5"
        ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-5"
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-4-5-20251001"
        ANTHROPIC_MODEL = "claude-sonnet-5"
        CLAUDE_CODE_SUBAGENT_MODEL = "sonnet[1m]"
        API_TIMEOUT_MS = "3000000"
        CLAUDE_DANGEROUSLY_SKIP_PERMISSIONS = "1"
        CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
        CLAUDE_CODE_NO_FLICKER = "1"
        CLAUDE_CODE_USE_POWERSHELL_TOOL = "1"
        MCP_TIMEOUT = "120000"
        MCP_TOOL_TIMEOUT = "120000"
    }
    permissions = [ordered]@{
        allow = @("Bash", "PowerShell", "Read", "Write", "Edit", "Glob", "Grep", "Task", "WebSearch", "FetchUrl")
        deny = @()
        defaultMode = "bypassPermissions"
    }
    model = "sonnet[1m]"
}

if ($hasHud) {
    $settingsObj["statusLine"] = [ordered]@{
        type = "command"
        command = "node $hudCmdJson"
    }
}
if ($hooksObj.Count -gt 0) {
    $settingsObj["hooks"] = $hooksObj
}

Write-Host "==> Xử lý cấu hình $targetSettingsPath..." -ForegroundColor Cyan
if (Test-Path $targetSettingsPath) {
    $bakSettingsPath = "$targetSettingsPath.bak"
    if ($isForce) {
        Write-Host "  -> File '$targetSettingsPath' đã tồn tại. [-Force / -OverwriteAll] Tự động sao lưu và ghi đè." -ForegroundColor Yellow
        if (-not $DryRun) {
            Copy-Item -Path $targetSettingsPath -Destination $bakSettingsPath -Force
            Write-Host "     Đã sao lưu sang $bakSettingsPath" -ForegroundColor DarkGray
            $outSettingsJson = $settingsObj | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($targetSettingsPath, $outSettingsJson, [System.Text.UTF8Encoding]::new($false))
        }
    } else {
        $choice = ""
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $choice = Read-Host "[?] File '$targetSettingsPath' đã tồn tại. Bạn có muốn [O]verwrite (ghi đè), [M]erge (hợp nhất cấu hình cũ và mới), hay [S]kip (bỏ qua)? [O/M/s]"
            $choice = if ($choice) { $choice.Trim() } else { "" }
        } else {
            $choice = "M"
        }

        if ($choice -match '^[mM]$' -or ($choice -eq "" -and (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected))) {
            Write-Host "  -> Đang hợp nhất cấu hình $targetSettingsPath (sao lưu sang $bakSettingsPath)..." -ForegroundColor Cyan
            if (-not $DryRun) {
                Copy-Item -Path $targetSettingsPath -Destination $bakSettingsPath -Force
                Write-Host "     Đã sao lưu sang $bakSettingsPath" -ForegroundColor DarkGray
                try {
                    $existingSettings = (Get-Content $targetSettingsPath -Raw -Encoding UTF8) | ConvertFrom-Json
                    if (-not $existingSettings) { $existingSettings = [PSCustomObject]@{} }

                    # Merge env
                    if (-not $existingSettings.PSObject.Properties['env']) {
                        $existingSettings | Add-Member -MemberType NoteProperty -Name 'env' -Value ([PSCustomObject]@{}) -Force
                    }
                    foreach ($k in $settingsObj.env.Keys) {
                        $existingSettings.env | Add-Member -MemberType NoteProperty -Name $k -Value $settingsObj.env[$k] -Force
                    }

                    # Merge permissions
                    if (-not $existingSettings.PSObject.Properties['permissions']) {
                        $existingSettings | Add-Member -MemberType NoteProperty -Name 'permissions' -Value ([PSCustomObject]@{ allow = @(); deny = @(); defaultMode = "bypassPermissions" }) -Force
                    }

                    # StatusLine
                    if ($hasHud) {
                        $existingSettings | Add-Member -MemberType NoteProperty -Name 'statusLine' -Value $settingsObj.statusLine -Force
                    } elseif ($existingSettings.PSObject.Properties['statusLine']) {
                        $existingSettings.PSObject.Properties.Remove('statusLine')
                    }

                    # Hooks
                    $existingSettings | Add-Member -MemberType NoteProperty -Name 'hooks' -Value $hooksObj -Force

                    $existingSettings | Add-Member -MemberType NoteProperty -Name 'model' -Value $settingsObj.model -Force

                    $outMerged = $existingSettings | ConvertTo-Json -Depth 10
                    [System.IO.File]::WriteAllText($targetSettingsPath, $outMerged, [System.Text.UTF8Encoding]::new($false))
                    Write-Host "     Hợp nhất settings.json thành công." -ForegroundColor Green
                } catch {
                    Write-Warning "Lỗi khi hợp nhất settings.json: $($_.Exception.Message)"
                }
            }
        } elseif ($choice -match '^[oO]$') {
            Write-Host "  -> Ghi đè file $targetSettingsPath (đã sao lưu sang $bakSettingsPath)" -ForegroundColor Green
            if (-not $DryRun) {
                Copy-Item -Path $targetSettingsPath -Destination $bakSettingsPath -Force
                Write-Host "     Đã sao lưu sang $bakSettingsPath" -ForegroundColor DarkGray
                $outSettingsJson = $settingsObj | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($targetSettingsPath, $outSettingsJson, [System.Text.UTF8Encoding]::new($false))
            }
        } else {
            Write-Host "  -> Bỏ qua $targetSettingsPath (giữ nguyên file hiện tại)." -ForegroundColor Yellow
        }
    }
} else {
    if (-not $DryRun) {
        $outSettingsJson = $settingsObj | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($targetSettingsPath, $outSettingsJson, [System.Text.UTF8Encoding]::new($false))
    }
}

# Xử lý CLAUDE.md
Write-Host "==> Cập nhật CLAUDE.md tại $ClaudeDir..." -ForegroundColor Cyan
$claudeMdTemplatePath = Join-Path $templatesDir "CLAUDE.md"
$claudeMdContent = ""
if (Test-Path $claudeMdTemplatePath) {
    $claudeMdContent = Get-Content -Path $claudeMdTemplatePath -Raw -Encoding UTF8
} else {
    $claudeMdSrc = Join-Path $PSScriptRoot "CLAUDE.md"
    if (Test-Path $claudeMdSrc) {
        $claudeMdContent = Get-Content -Path $claudeMdSrc -Raw -Encoding UTF8
    }
}

if ($EnableMemorix) {
    $memorixSecPath = Join-Path $templatesDir "memorix-claude-section.md"
    if (Test-Path $memorixSecPath) {
        $memorixSec = Get-Content -Path $memorixSecPath -Raw -Encoding UTF8
        if ($claudeMdContent -notmatch "Memorix — Memory Tools") {
            $claudeMdContent = $claudeMdContent + "`n`n" + $memorixSec
        }
    }
}

$targetClaudeMd = Join-Path $ClaudeDir "CLAUDE.md"
if (Test-Path $targetClaudeMd) {
    $bakClaudeMd = "$targetClaudeMd.bak"
    if ($isForce) {
        if (-not $DryRun) {
            Copy-Item -Path $targetClaudeMd -Destination $bakClaudeMd -Force
            [System.IO.File]::WriteAllText($targetClaudeMd, $claudeMdContent, [System.Text.UTF8Encoding]::new($false))
        }
    } else {
        $choice = ""
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $choice = Read-Host "[?] File '$targetClaudeMd' đã tồn tại. Bạn có muốn [O]verwrite (ghi đè) hay [S]kip (bỏ qua)? [O/s]"
            $choice = if ($choice) { $choice.Trim() } else { "" }
        } else {
            $choice = "O"
        }
        if ($choice -match '^[oO]$' -or ($choice -eq "" -and (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected))) {
            if (-not $DryRun) {
                Copy-Item -Path $targetClaudeMd -Destination $bakClaudeMd -Force
                [System.IO.File]::WriteAllText($targetClaudeMd, $claudeMdContent, [System.Text.UTF8Encoding]::new($false))
            }
        }
    }
} else {
    if (-not $DryRun) {
        [System.IO.File]::WriteAllText($targetClaudeMd, $claudeMdContent, [System.Text.UTF8Encoding]::new($false))
    }
}

# Dọn dẹp các tài liệu cũ không còn dùng và chuyển vào Thùng rác (Recycle Bin)
$legacyFiles = @("SYSTEM.md", "AGENTS.md", "RULES.md")
foreach ($leg in $legacyFiles) {
    $oldFilePath = Join-Path $ClaudeDir $leg
    if (Test-Path $oldFilePath) {
        Write-Host "==> Dọn dẹp tài liệu cũ: $oldFilePath (chuyển vào Thùng rác)..." -ForegroundColor Cyan
        if (-not $DryRun) {
            Move-ToRecycleBinFile -Path $oldFilePath
        }
    }
}

# Xử lý thư mục skills
$srcSkillsDir = Join-Path $PSScriptRoot "skills"
$targetSkillsDir = Join-Path $ClaudeDir "skills"
if (Test-Path $srcSkillsDir) {
    Write-Host "==> Đồng bộ skills vào $targetSkillsDir..." -ForegroundColor Cyan
    if (-not (Test-Path $targetSkillsDir) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $targetSkillsDir -Force | Out-Null
    }

    $skillFolders = Get-ChildItem -Path $srcSkillsDir -Directory
    foreach ($sf in $skillFolders) {
        $isMemorixSkill = $sf.Name.StartsWith("memorix-")
        if (-not $EnableMemorix -and $isMemorixSkill) {
            continue
        }
        $destSf = Join-Path $targetSkillsDir $sf.Name
        if (-not $DryRun) {
            if (-not (Test-Path $destSf)) {
                New-Item -ItemType Directory -Path $destSf -Force | Out-Null
            }
            Copy-Item -Path "$($sf.FullName)\*" -Destination $destSf -Recurse -Force
        }
    }

    # Nếu $EnableMemorix = $false: gỡ bỏ các thư mục skills memorix-* đã tồn tại trước đó sang Thùng rác
    if (-not $EnableMemorix -and (Test-Path $targetSkillsDir)) {
        $existingMemorixSkills = Get-ChildItem -Path $targetSkillsDir -Directory -Filter "memorix-*"
        foreach ($ems in $existingMemorixSkills) {
            Write-Host "==> Gỡ bỏ skill memorix cũ: $($ems.FullName) (chuyển vào Thùng rác)..." -ForegroundColor Cyan
            if (-not $DryRun) {
                Move-ToRecycleBinDirectory -Path $ems.FullName
            }
        }
    }
}

Write-Host "==> Hoàn tất thiết lập môi trường Claude Code!" -ForegroundColor Green
