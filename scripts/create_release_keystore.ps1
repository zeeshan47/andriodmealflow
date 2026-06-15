$ErrorActionPreference = "Stop"

function Fail($message) {
    Write-Host ""
    Write-Host "ERROR: $message" -ForegroundColor Red
    exit 1
}

function SecureStringToText($secure) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Find-Keytool {
    $fromPath = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($fromPath) {
        return $fromPath.Source
    }

    $androidStudioKeytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $androidStudioKeytool) {
        return $androidStudioKeytool
    }

    if (![string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $javaHomeKeytool = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $javaHomeKeytool) {
            return $javaHomeKeytool
        }
    }

    return $null
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SigningDir = Join-Path $RepoRoot "signing"
$KeyStoreRelativePath = "signing/fastpos-release.jks"
$KeyStorePath = Join-Path $RepoRoot $KeyStoreRelativePath
$KeyPropertiesPath = Join-Path $RepoRoot "key.properties"

Set-Location $RepoRoot

if (Test-Path $KeyStorePath) {
    Fail "Signing key already exists at $KeyStorePath. Keep using it for updates, or move it away manually if you really need a new key."
}

if (Test-Path $KeyPropertiesPath) {
    Fail "key.properties already exists. Move or delete it manually before creating a new release key."
}

$keytool = Find-Keytool
if (!$keytool) {
    Fail "keytool.exe was not found. Install Android Studio or set JAVA_HOME."
}

$alias = Read-Host "Key alias [fastpos]"
if ([string]::IsNullOrWhiteSpace($alias)) {
    $alias = "fastpos"
}

$storePasswordSecure = Read-Host "Keystore password" -AsSecureString
$keyPasswordSecure = Read-Host "Key password" -AsSecureString
$storePassword = SecureStringToText $storePasswordSecure
$keyPassword = SecureStringToText $keyPasswordSecure

if ($storePassword.Length -lt 6 -or $keyPassword.Length -lt 6) {
    Fail "Android keystore passwords must be at least 6 characters."
}

New-Item -ItemType Directory -Path $SigningDir -Force | Out-Null

Write-Host ""
Write-Host "Creating release signing key..." -ForegroundColor Cyan
& $keytool `
    -genkeypair `
    -v `
    -keystore $KeyStorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $alias `
    -storepass $storePassword `
    -keypass $keyPassword `
    -dname "CN=FastPOS Android, OU=FastPOS, O=FastPOS, L=Karachi, S=Sindh, C=PK"

if ($LASTEXITCODE -ne 0) {
    Fail "keytool failed to create the release key."
}

@"
storeFile=$KeyStoreRelativePath
storePassword=$storePassword
keyAlias=$alias
keyPassword=$keyPassword
"@ | Set-Content -Path $KeyPropertiesPath -NoNewline

Write-Host ""
Write-Host "Release signing is configured." -ForegroundColor Green
Write-Host "Created: $KeyStorePath"
Write-Host "Created: $KeyPropertiesPath"
Write-Host ""
Write-Host "Back up both files somewhere safe. If this key is lost, installed customer apps cannot be updated."
