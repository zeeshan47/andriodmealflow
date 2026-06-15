param(
    [Parameter(Mandatory = $false)]
    [string]$VersionName
)

$ErrorActionPreference = "Stop"

function Fail($message) {
    Write-Host ""
    Write-Host "ERROR: $message" -ForegroundColor Red
    exit 1
}

function Run($file, $arguments, $description) {
    Write-Host ""
    Write-Host $description -ForegroundColor Cyan
    & $file @arguments
    if ($LASTEXITCODE -ne 0) {
        Fail "$description failed."
    }
}

function Find-Gradle {
    $gradlew = Join-Path $RepoRoot "gradlew.bat"
    if (Test-Path $gradlew) {
        return $gradlew
    }

    $pathGradle = Get-Command gradle.bat -ErrorAction SilentlyContinue
    if ($pathGradle) {
        return $pathGradle.Source
    }

    $pathGradle = Get-Command gradle -ErrorAction SilentlyContinue
    if ($pathGradle) {
        return $pathGradle.Source
    }

    $wrapperRoot = Join-Path $env:USERPROFILE ".gradle\wrapper\dists"
    if (Test-Path $wrapperRoot) {
        $candidate = Get-ChildItem -Path $wrapperRoot -Recurse -Filter gradle.bat -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    return $null
}

function Get-BuildConfigValue($content, $key) {
    $pattern = 'buildConfigField\("String",\s*"' + [regex]::Escape($key) + '",\s*"\\"([^"]*)\\""\)'
    $match = [regex]::Match($content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return ""
}

function Test-GhCommand {
    param(
        [string[]]$CommandArguments
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & gh @CommandArguments *> $null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    return $exitCode -eq 0
}

function Read-KeyProperties {
    $properties = @{}
    if (!(Test-Path $KeyPropertiesFile)) {
        return $properties
    }

    foreach ($line in Get-Content -Path $KeyPropertiesFile) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
            continue
        }
        $index = $trimmed.IndexOf("=")
        if ($index -lt 1) {
            continue
        }
        $name = $trimmed.Substring(0, $index).Trim()
        $value = $trimmed.Substring($index + 1).Trim()
        $properties[$name] = $value
    }

    return $properties
}

if ([string]::IsNullOrWhiteSpace($VersionName)) {
    $VersionName = Read-Host "Enter new version number, for example 1.1"
}

$VersionName = $VersionName.Trim()
if ($VersionName -notmatch '^\d+(\.\d+){0,3}([-_A-Za-z0-9.]+)?$') {
    Fail "Version number '$VersionName' is not valid. Use values like 1.1 or 1.2.0."
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$BuildFile = Join-Path $RepoRoot "app\build.gradle.kts"
$DistDir = Join-Path $RepoRoot "dist"
$KeyPropertiesFile = Join-Path $RepoRoot "key.properties"

if (!(Test-Path $BuildFile)) {
    Fail "Cannot find app\build.gradle.kts. Run this command from the project folder."
}

Set-Location $RepoRoot

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is not installed or not available in PATH."
}

if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI is not installed. Install it from https://cli.github.com/ then run: gh auth login"
}

Run "gh" @("auth", "status") "Checking GitHub login"

$buildText = Get-Content -Path $BuildFile -Raw
$owner = Get-BuildConfigValue $buildText "GITHUB_UPDATE_OWNER"
$repo = Get-BuildConfigValue $buildText "GITHUB_UPDATE_REPO"

if ([string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($repo)) {
    Fail "GitHub updater owner/repo is not configured in app\build.gradle.kts."
}

$repoSlug = "$owner/$repo"
Write-Host ""
Write-Host "Checking GitHub repository access for $repoSlug..." -ForegroundColor Cyan
if (!(Test-GhCommand -CommandArguments @("repo", "view", $repoSlug))) {
    Fail "GitHub CLI cannot access $repoSlug. Check the repo name, then run: gh auth login -h github.com -s repo"
}

$versionCodeMatch = [regex]::Match($buildText, 'versionCode\s*=\s*(\d+)')
if (!$versionCodeMatch.Success) {
    Fail "Could not find versionCode in app\build.gradle.kts."
}

$versionNameMatch = [regex]::Match($buildText, 'versionName\s*=\s*"([^"]+)"')
if (!$versionNameMatch.Success) {
    Fail "Could not find versionName in app\build.gradle.kts."
}

$currentVersionCode = [int]$versionCodeMatch.Groups[1].Value
$currentVersionName = $versionNameMatch.Groups[1].Value
$newVersionCode = if ($currentVersionName -eq $VersionName) {
    $currentVersionCode
} else {
    $currentVersionCode + 1
}

$buildText = [regex]::Replace($buildText, 'versionCode\s*=\s*\d+', "versionCode    = $newVersionCode", 1)
$buildText = [regex]::Replace($buildText, 'versionName\s*=\s*"[^"]+"', "versionName    = `"$VersionName`"", 1)
Set-Content -Path $BuildFile -Value $buildText -NoNewline

Write-Host ""
if ($currentVersionName -eq $VersionName) {
    Write-Host "Version is already $VersionName, keeping versionCode $newVersionCode." -ForegroundColor Green
} else {
    Write-Host "Version updated to $VersionName, versionCode $newVersionCode." -ForegroundColor Green
}

$gradle = Find-Gradle
if (!$gradle) {
    Fail "Gradle was not found. Add gradle to PATH or add gradlew.bat to this project."
}

$androidStudioJbr = "C:\Program Files\Android\Android Studio\jbr"
if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME) -and (Test-Path $androidStudioJbr)) {
    $env:JAVA_HOME = $androidStudioJbr
}

$keyProperties = Read-KeyProperties
$storeFileValue = $keyProperties["storeFile"]
$storeFilePath = if ([string]::IsNullOrWhiteSpace($storeFileValue)) { "" } else { Join-Path $RepoRoot $storeFileValue }
$releaseSigningConfigured = (Test-Path $KeyPropertiesFile) -and
    !([string]::IsNullOrWhiteSpace($storeFileValue)) -and
    (Test-Path $storeFilePath) -and
    !([string]::IsNullOrWhiteSpace($keyProperties["storePassword"])) -and
    !([string]::IsNullOrWhiteSpace($keyProperties["keyAlias"])) -and
    !([string]::IsNullOrWhiteSpace($keyProperties["keyPassword"]))

if (!$releaseSigningConfigured) {
    Fail "Release signing is not configured. Run create_release_keystore.cmd first, then publish again."
}

$buildTask = ":app:assembleRelease"
$buildType = "release"

Run $gradle @($buildTask) "Building signed release APK"

$apkFolder = Join-Path $RepoRoot "app\build\outputs\apk\$buildType"
$apk = Get-ChildItem -Path $apkFolder -Filter "*.apk" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (!$apk) {
    Fail "APK was not created in $apkFolder."
}

if ($apk.Name -match "unsigned") {
    Fail "The APK is unsigned. Configure release signing before uploading updates."
}

New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
$assetName = "fastpos-v$VersionName-$buildType.apk"
$assetPath = Join-Path $DistDir $assetName
Copy-Item -Path $apk.FullName -Destination $assetPath -Force

Run "git" @("add", "app/build.gradle.kts") "Staging version update"

$pendingCommit = git status --short app/build.gradle.kts
if ($pendingCommit) {
    Run "git" @("commit", "-m", "Release v$VersionName") "Committing version update"
} else {
    Write-Host ""
    Write-Host "No version file changes to commit." -ForegroundColor Yellow
}

Run "git" @("push") "Pushing code to GitHub"

$tag = "v$VersionName"
$releaseTitle = "FastPOS Android $tag"
$releaseNotes = "FastPOS Android update $tag."

Write-Host ""
Write-Host "Uploading $assetName to GitHub release $tag..." -ForegroundColor Cyan
if (Test-GhCommand -CommandArguments @("release", "view", $tag, "--repo", $repoSlug)) {
    Run "gh" @("release", "upload", $tag, $assetPath, "--repo", $repoSlug, "--clobber") "Uploading APK to existing release"
} else {
    Run "gh" @("release", "create", $tag, $assetPath, "--repo", $repoSlug, "--title", $releaseTitle, "--notes", $releaseNotes) "Creating GitHub release"
}

Write-Host ""
Write-Host "Done. GitHub release is ready: https://github.com/$repoSlug/releases/tag/$tag" -ForegroundColor Green
