<#
.SYNOPSIS
    Builds the Micro Devos release APK with live Supabase credentials from .env.
.DESCRIPTION
    Loads SUPABASE_URL and SUPABASE_ANON_KEY from the project root .env,
    verifies both are non-empty, and runs:
      flutter clean
      flutter pub get
      flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
#>

[CmdletBinding()]
param (
    [switch]$Install,
    [string]$DeviceId
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$envPath = Join-Path $projectRoot ".env"

if (-not (Test-Path $envPath)) {
    Write-Error "ERROR: Missing .env file at '$envPath'. Please create it with SUPABASE_URL and SUPABASE_ANON_KEY."
    exit 1
}

$supabaseUrl = ""
$supabaseAnonKey = ""
$geminiApiKey = ""

foreach ($line in (Get-Content -Path $envPath)) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith("#") -or $trimmed -eq "") {
        continue
    }
    if ($trimmed -match '^SUPABASE_URL\s*=\s*(.*)$') {
        $val = $matches[1].Trim().Trim('"').Trim("'")
        $supabaseUrl = $val
    }
    elseif ($trimmed -match '^SUPABASE_ANON_KEY\s*=\s*(.*)$') {
        $val = $matches[1].Trim().Trim('"').Trim("'")
        $supabaseAnonKey = $val
    }
    elseif ($trimmed -match '^GEMINI_API_KEY\s*=\s*(.*)$') {
        $val = $matches[1].Trim().Trim('"').Trim("'")
        $geminiApiKey = $val
    }
}

if ([string]::IsNullOrWhiteSpace($supabaseUrl)) {
    Write-Error "ERROR: SUPABASE_URL is missing or empty in '$envPath'."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
    Write-Error "ERROR: SUPABASE_ANON_KEY is missing or empty in '$envPath'."
    exit 1
}

Write-Host "==> Verified .env configuration: Supabase URL host found, anon key loaded." -ForegroundColor Green
Write-Host "==> Cleaning build artifacts..." -ForegroundColor Cyan
Set-Location $projectRoot
& flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter clean failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "==> Resolving Flutter dependencies..." -ForegroundColor Cyan
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter pub get failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "==> Building release APK with live credentials..." -ForegroundColor Cyan
$buildArgs = @(
    "build",
    "apk",
    "--release",
    "--dart-define=SUPABASE_URL=$supabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
)
if (-not [string]::IsNullOrWhiteSpace($geminiApiKey)) {
    $buildArgs += "--dart-define=GEMINI_API_KEY=$geminiApiKey"
}

& flutter @buildArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter build apk failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}

$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
Write-Host "==> Release APK successfully built: $apkPath" -ForegroundColor Green

if ($Install) {
    Write-Host "==> Installing APK to connected device..." -ForegroundColor Cyan
    $adbArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $adbArgs += @("-s", $DeviceId)
    }
    $adbArgs += @("install", "-r", $apkPath)
    & adb @adbArgs
}
