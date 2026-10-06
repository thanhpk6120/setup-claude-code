$ErrorActionPreference = "Stop"

$tempDir = Join-Path $env:TEMP ("claude-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempJson = Join-Path $env:TEMP ("claude-test-" + [System.Guid]::NewGuid().ToString("N") + ".json")

try {
    $env:AI_BASE_URL = "https://test.local"
    $env:AI_API_KEY = "test-key-abc"
    $env:JIRA_URL = "https://test.jira"
    $env:JIRA_PERSONAL_TOKEN = "test-jira-token"
    $env:CONFLUENCE_URL = "https://test.conf"
    $env:CONFLUENCE_PERSONAL_TOKEN = "test-conf-token"
    $env:CONTEXT7_API_KEY = "test-ctx-token"
    $env:GITLAB_HOST = "10.30.1.17"
    $env:GITLAB_TOKEN = ""

    $mockBinDir = Join-Path $env:TEMP ("claude-mock-bin-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $mockBinDir | Out-Null
    Set-Content -Path (Join-Path $mockBinDir "gitnexus.cmd") -Value "@echo off`necho gitnexus"
    $oldPath = $env:Path
    $env:Path = "$mockBinDir;$env:Path"

    $mockNpmDir = Join-Path $env:TEMP ("claude-mock-npm-" + [System.Guid]::NewGuid().ToString("N"))
    $mockContext7Path = Join-Path $mockNpmDir "@upstash\context7-mcp\dist"
    New-Item -ItemType Directory -Force -Path $mockContext7Path | Out-Null
    Set-Content -Path (Join-Path $mockContext7Path "index.js") -Value "// mock"

    function global:npm { param([Parameter(ValueFromRemainingArguments)]$r) if ($r -contains "root" -and $r -contains "-g") { return $mockNpmDir } }

    Write-Host "Running bootstrap into temp dir: $tempDir"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -ClaudeDir $tempDir -ClaudeJson $tempJson

    if (-not (Test-Path $tempJson)) { throw "ASSERTION FAILED: claude json missing" }
    $mcpRaw = Get-Content $tempJson -Raw
    $mcpJson = $mcpRaw | ConvertFrom-Json
    if (-not $mcpJson.mcpServers.gitnexus -or -not $mcpJson.mcpServers.'company-atlassian' -or -not $mcpJson.mcpServers.context7 -or -not $mcpJson.mcpServers.glab -or -not $mcpJson.mcpServers.cloakbrowser -or -not $mcpJson.mcpServers.memorix) {
        throw "ASSERTION FAILED: Missing mcp tools in json"
    }

    if ($mcpJson.mcpServers.memorix.command -ne "memorix") {
        throw "ASSERTION FAILED: memorix command should be 'memorix', but was '$($mcpJson.mcpServers.memorix.command)'"
    }
    if ($mcpJson.mcpServers.memorix.args -contains "npx" -or $mcpJson.mcpServers.memorix.args -contains "memorix@latest") {
        throw "ASSERTION FAILED: memorix args contains npx"
    }

    if ($mcpJson.mcpServers.glab.command -ne "glab") {
        throw "ASSERTION FAILED: glab command should be 'glab', but was '$($mcpJson.mcpServers.glab.command)'"
    }

    $claudeMd = Join-Path $tempDir "CLAUDE.md"
    if (-not (Test-Path $claudeMd)) { throw "ASSERTION FAILED: CLAUDE.md missing" }
    $claudeMdContent = Get-Content $claudeMd -Raw
    if ($claudeMdContent -notmatch "Root Project Agent Guide" -or $claudeMdContent -notmatch "Pre-flight Task Complexity" -or $claudeMdContent -notmatch "Global Rules") {
        throw "ASSERTION FAILED: CLAUDE.md missing markers from old source files"
    }

    foreach ($oldFile in @("SYSTEM.md", "AGENTS.md", "RULES.md")) {
        if (Test-Path (Join-Path $tempDir $oldFile)) {
            throw "ASSERTION FAILED: $oldFile should not exist in temp dir"
        }
    }

    $skillsDir = Join-Path $tempDir "skills"
    if (-not (Test-Path $skillsDir)) { throw "ASSERTION FAILED: skills/ missing" }
    Write-Host "TEST PASSED: setup-claude-code bootstrap verified." -ForegroundColor Green
} finally {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    if (Test-Path $tempJson) { Remove-Item -Force $tempJson -ErrorAction SilentlyContinue }
    if (Test-Path $mockBinDir) { Remove-Item -Recurse -Force $mockBinDir -ErrorAction SilentlyContinue }
    if (Test-Path $mockNpmDir) { Remove-Item -Recurse -Force $mockNpmDir -ErrorAction SilentlyContinue }
    if ($oldPath) { $env:Path = $oldPath }
}
