# install.ps1 - One-line interactive installer for setup-claude-code
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$OverwriteAll,
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$EnableMemorix,
    [switch]$DisableMemorix,
    [string]$ClaudeDir = "$env:USERPROFILE\.claude"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "       SETUP-CLAUDE-CODE INSTALLER - INTERACTIVE SETUP          " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Kiểm tra Claude Code CLI trong PATH
Write-Host "==> Kiểm tra Claude Code CLI trong hệ thống..." -ForegroundColor Cyan
$claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Host "[!] Claude Code CLI chưa được cài đặt trong PATH." -ForegroundColor Yellow
    $installClaudePrompt = Read-Host "Claude Code CLI chưa được cài đặt. Bạn có muốn cài đặt Claude Code chính gốc ngay bây giờ không? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($installClaudePrompt) -or $installClaudePrompt.Trim().ToLower() -eq 'y') {
        # Nhận diện terminal
        $terminalType = if ($PSVersionTable.PSEdition -eq "Core") {
            "PowerShell Core (pwsh)"
        } elseif ($env:WT_SESSION) {
            "Windows Terminal ($($PSVersionTable.PSEdition))"
        } elseif ($PSVersionTable.PSVersion) {
            "Windows PowerShell"
        } else {
            "CMD / Standard Console"
        }
        Write-Host "==> Nhận diện terminal: $terminalType (PSVersion: $($PSVersionTable.PSVersion))." -ForegroundColor Cyan

        # Kiểm tra node và npm trước khi cài đặt
        Write-Host "==> Kiểm tra Node.js và npm..." -ForegroundColor Cyan
        $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
        $npmCmd = Get-Command "npm" -ErrorAction SilentlyContinue
        if (-not $nodeCmd -or -not $npmCmd) {
            throw "Lỗi: Node.js và npm là bắt buộc để cài đặt Claude Code CLI. Vui lòng cài đặt Node.js (>= 22.18.0) trước."
        }

        Write-Host "==> Đang cài đặt Claude Code chính gốc: npm install -g @anthropic-ai/claude-code..." -ForegroundColor Cyan
        npm install -g @anthropic-ai/claude-code
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Cài đặt @anthropic-ai/claude-code trả về mã trạng thái: $LASTEXITCODE"
        } else {
            Write-Host "==> Cài đặt Claude Code CLI thành công!" -ForegroundColor Green
        }

        # Nạp lại $env:PATH trong session hiện tại
        Write-Host "==> Đang nạp lại biến môi trường PATH trong session hiện tại..." -ForegroundColor Cyan
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        $npmPrefix = ""
        try {
            $npmPrefix = (npm config get prefix 2>$null).Trim()
        } catch {}

        $searchPaths = @(
            "$env:APPDATA\npm",
            "$env:LOCALAPPDATA\npm",
            $npmPrefix,
            "$env:USERPROFILE\.local\bin"
        )
        $allPaths = (@($searchPaths) + ($userPath -split ';') + ($machinePath -split ';') + ($env:PATH -split ';')) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } |
            Select-Object -Unique
        $env:PATH = ($allPaths -join ';')

        $claudeCheck = Get-Command "claude" -ErrorAction SilentlyContinue
        if ($claudeCheck) {
            Write-Host "==> Đã nhận diện lệnh 'claude' tại: $($claudeCheck.Source)" -ForegroundColor Green
        } else {
            Write-Warning "Lệnh 'claude' chưa nhận diện được ngay qua Get-Command. Bạn có thể cần mở lại terminal sau khi cài đặt hoàn tất."
        }
    } else {
        Write-Host "[-] Đã bỏ qua cài đặt Claude Code CLI theo lựa chọn của người dùng." -ForegroundColor Yellow
    }
} else {
    Write-Host "==> Đã phát hiện Claude Code CLI tại: $($claudeCmd.Source)" -ForegroundColor Green
}

# 2. Luồng hỏi tương tác cấu hình AI Provider
Write-Host ""
Write-Host "==> Cấu hình kết nối AI Provider..." -ForegroundColor Cyan
$defaultAiUrl = if ($env:AI_BASE_URL) { $env:AI_BASE_URL } else { "http://localhost:20128/v1" }
$inputAiUrl = Read-Host "Nhập AI Base URL [Mặc định: $defaultAiUrl]"
$aiBaseUrl = if ([string]::IsNullOrWhiteSpace($inputAiUrl)) { $defaultAiUrl } else { $inputAiUrl.Trim() }

# AI_API_KEY: Bắt buộc nhập, không được có key mặc định. Vòng lặp bắt buộc.
$aiApiKey = ""
if (-not [string]::IsNullOrWhiteSpace($env:AI_API_KEY)) {
    $existingKeyHint = if ($env:AI_API_KEY.Length -gt 6) {
        $env:AI_API_KEY.Substring(0, 4) + "..." + $env:AI_API_KEY.Substring($env:AI_API_KEY.Length - 2)
    } else {
        "******"
    }
    $inputKey = Read-Host "Nhập AI API Key (Bắt buộc) [Nhấn Enter để giữ giá trị hiện tại từ môi trường: $existingKeyHint]"
    if ([string]::IsNullOrWhiteSpace($inputKey)) {
        $aiApiKey = $env:AI_API_KEY.Trim()
    } else {
        $aiApiKey = $inputKey.Trim()
    }
}

while ([string]::IsNullOrWhiteSpace($aiApiKey)) {
    if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
        throw "Lỗi: Đang chạy ở chế độ non-interactive nhưng AI API Key chưa được cung cấp qua biến môi trường `$env:AI_API_KEY`."
    }
    $inputKey = Read-Host "Nhập AI API Key (Bắt buộc)"
    if (-not [string]::IsNullOrWhiteSpace($inputKey)) {
        $aiApiKey = $inputKey.Trim()
        break
    }
    Write-Host "Lỗi: AI API Key là bắt buộc, không được để trống. Vui lòng nhập lại!" -ForegroundColor Red
}

# 3. Cấu hình hệ thống tích hợp (Tùy chọn, ấn Enter để bỏ qua nếu không nhập)
Write-Host ""
Write-Host "==> Cấu hình các hệ thống tích hợp (Tùy chọn, nhấn Enter để bỏ qua)..." -ForegroundColor Cyan

# Jira
$defaultJiraUrl = if ($env:JIRA_URL) { $env:JIRA_URL } else { "https://jira.cybertech.vn" }
$inputJiraUrl = Read-Host "Nhập Jira URL [Mặc định: $defaultJiraUrl] (Nhấn Enter để dùng mặc định, hoặc nhập URL khác)"
$jiraUrl = if ([string]::IsNullOrWhiteSpace($inputJiraUrl)) { $defaultJiraUrl } else { $inputJiraUrl.Trim() }

$inputJiraToken = Read-Host "Nhập Jira Personal Token [Nhấn Enter để bỏ qua nếu không dùng Jira]"
$jiraToken = if ([string]::IsNullOrWhiteSpace($inputJiraToken)) { "" } else { $inputJiraToken.Trim() }

# Confluence
$defaultConfUrl = if ($env:CONFLUENCE_URL) { $env:CONFLUENCE_URL } else { "https://conf.cybertech.vn" }
$inputConfUrl = Read-Host "Nhập Confluence URL [Mặc định: $defaultConfUrl] (Nhấn Enter để dùng mặc định, hoặc nhập URL khác)"
$confUrl = if ([string]::IsNullOrWhiteSpace($inputConfUrl)) { $defaultConfUrl } else { $inputConfUrl.Trim() }

$inputConfToken = Read-Host "Nhập Confluence Personal Token [Nhấn Enter để bỏ qua nếu không dùng Confluence]"
$confToken = if ([string]::IsNullOrWhiteSpace($inputConfToken)) { "" } else { $inputConfToken.Trim() }

# GitLab
$defaultGitlabHost = if ($env:GITLAB_HOST) { $env:GITLAB_HOST } else { "10.30.1.17" }
$inputGitlabHost = Read-Host "Nhập GitLab Host [Mặc định: $defaultGitlabHost] (Nhấn Enter để dùng mặc định, hoặc nhập Host khác)"
$gitlabHost = if ([string]::IsNullOrWhiteSpace($inputGitlabHost)) { $defaultGitlabHost } else { $inputGitlabHost.Trim() }

$inputGitlabToken = Read-Host "Nhập GitLab Personal Token [Nhấn Enter để bỏ qua nếu không dùng GitLab]"
$gitlabToken = if ([string]::IsNullOrWhiteSpace($inputGitlabToken)) { "" } else { $inputGitlabToken.Trim() }

# Context7
$inputCtxKey = Read-Host "Nhập Context7 API Key [Nhấn Enter để bỏ qua nếu không dùng Context7]"
$context7Key = if ([string]::IsNullOrWhiteSpace($inputCtxKey)) { "" } else { $inputCtxKey.Trim() }

# 4. Tùy chọn Memorix
Write-Host ""
Write-Host "==> Kiểm tra tiện ích Memorix..." -ForegroundColor Cyan
$existingMemorix = Get-Command "memorix" -ErrorAction SilentlyContinue
$enableMemorixVal = $false

if ($PSBoundParameters.ContainsKey('EnableMemorix')) {
    $enableMemorixVal = $EnableMemorix.IsPresent
} elseif ($PSBoundParameters.ContainsKey('DisableMemorix')) {
    $enableMemorixVal = -not $DisableMemorix.IsPresent
} elseif ($existingMemorix) {
    Write-Host "==> Đã phát hiện Memorix trên máy (tại: $($existingMemorix.Source))." -ForegroundColor Green
    Write-Host "==> Tự động kích hoạt và cập nhật Memorix lên phiên bản mới nhất..." -ForegroundColor Green
    $enableMemorixVal = $true
} else {
    $memorixPrompt = Read-Host "Bạn có muốn cài đặt Memorix (MCP & Session Memory) không? [y/N]"
    if (-not [string]::IsNullOrWhiteSpace($memorixPrompt) -and $memorixPrompt.Trim().ToLower() -eq 'y') {
        $enableMemorixVal = $true
        Write-Host "==> Đã kích hoạt cài đặt Memorix." -ForegroundColor Green
    } else {
        $enableMemorixVal = $false
        Write-Host "==> Bỏ qua cài đặt Memorix (mặc định)." -ForegroundColor Yellow
    }
}

# 5. Thiết lập biến môi trường phiên làm việc
$env:AI_BASE_URL = $aiBaseUrl
$env:AI_API_KEY = $aiApiKey
if ($jiraUrl) { $env:JIRA_URL = $jiraUrl }
if ($jiraToken) { $env:JIRA_PERSONAL_TOKEN = $jiraToken }
if ($confUrl) { $env:CONFLUENCE_URL = $confUrl }
if ($confToken) { $env:CONFLUENCE_PERSONAL_TOKEN = $confToken }
if ($gitlabHost) { $env:GITLAB_HOST = $gitlabHost }
if ($gitlabToken) { $env:GITLAB_TOKEN = $gitlabToken }
if ($context7Key) { $env:CONTEXT7_API_KEY = $context7Key }

# Chuẩn bị nội dung file .env tạm thời
$envContent = @"
AI_BASE_URL=$aiBaseUrl
AI_API_KEY=$aiApiKey
JIRA_URL=$jiraUrl
JIRA_PERSONAL_TOKEN=$jiraToken
CONFLUENCE_URL=$confUrl
CONFLUENCE_PERSONAL_TOKEN=$confToken
CONTEXT7_API_KEY=$context7Key
GITLAB_HOST=$gitlabHost
GITLAB_TOKEN=$gitlabToken
"@

$zipUrl = "https://github.com/thanhpk6120/setup-claude-code/archive/refs/heads/main.zip"
$tempBase = Join-Path $env:TEMP ("claude-code-install-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("claude-code-repo-" + [System.Guid]::NewGuid().ToString("N") + ".zip")

try {
    # Tạo thư mục tạm
    New-Item -ItemType Directory -Path $tempBase -Force | Out-Null

    # Lưu file .env tạm thời tại thư mục gốc tạm
    $tempEnvPath = Join-Path $tempBase ".env"
    Set-Content -Path $tempEnvPath -Value $envContent -Encoding UTF8

    Write-Host "==> Đang tải gói setup-claude-code từ GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    Write-Host "==> Đang giải nén tập tin..." -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath $tempBase -Force

    $extractedRoot = Join-Path $tempBase "setup-claude-code-main"
    if (-not (Test-Path $extractedRoot)) {
        $found = Get-ChildItem -Directory $tempBase | Where-Object { $_.Name -ne "setup-claude-code-main" } | Select-Object -First 1
        if ($found) { $extractedRoot = $found.FullName }
    }

    if (-not (Test-Path $extractedRoot)) {
        throw "Lỗi: Không tìm thấy thư mục package đã giải nén trong $tempBase."
    }

    # Sao chép file .env tạm thời vào thư mục mã nguồn giải nén để bootstrap.ps1 đọc
    $extractedEnvPath = Join-Path $extractedRoot ".env"
    Copy-Item -Path $tempEnvPath -Destination $extractedEnvPath -Force

    $bootstrapScript = Join-Path $extractedRoot "bootstrap.ps1"
    if (-not (Test-Path $bootstrapScript)) {
        throw "Lỗi: Không tìm thấy bootstrap.ps1 trong gói cài đặt tại: $bootstrapScript"
    }
    # Chuẩn bị tham số gọi bootstrap.ps1
    $bootstrapParams = @{}
    if ($DryRun) { $bootstrapParams["DryRun"] = $true }
    if ($SkipInstall) { $bootstrapParams["SkipInstall"] = $true }
    if ($Force) { $bootstrapParams["Force"] = $true }
    if ($OverwriteAll) { $bootstrapParams["OverwriteAll"] = $true }
    if ($ClaudeDir) { $bootstrapParams["ClaudeDir"] = $ClaudeDir }
    if ($enableMemorixVal) {
        $bootstrapParams["EnableMemorix"] = $true
    } else {
        $bootstrapParams["DisableMemorix"] = $true
    }

    Write-Host "==> Đang khởi chạy bootstrap.ps1 với các tham số đã chọn..." -ForegroundColor Cyan
    & $bootstrapScript @bootstrapParams
} finally {
    Write-Host "==> Dọn dẹp tài nguyên tạm thời vào Thùng rác (Recycle Bin)..." -ForegroundColor Cyan
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

    if (Test-Path $zipFile) {
        try {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $zipFile,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        } catch {
            Write-Warning "Không thể chuyển file zip tạm vào Thùng rác: $($_.Exception.Message)"
        }
    }

    if (Test-Path $tempBase) {
        try {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $tempBase,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        } catch {
            Write-Warning "Không thể chuyển thư mục tạm vào Thùng rác: $($_.Exception.Message)"
        }
    }
}
