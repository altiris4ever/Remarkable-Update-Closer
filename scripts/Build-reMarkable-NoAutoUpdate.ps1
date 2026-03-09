<#
.SYNOPSIS
    Builds a WinSparkle stub DLL for disabling the reMarkable auto-updater.

.DESCRIPTION
    Intended for use in a disposable VM or packaging environment.

    The script:
    1. Resolves the latest reMarkable installer URL from winget-pkgs by scraping the GitHub HTML page.
    2. Falls back to winstall.app if winget-pkgs lookup fails.
    3. Falls back to a hardcoded reMarkable URL if both lookups fail.
    4. Resolves the latest MinGW build from the latest GitHub release page.
    5. Falls back to a hardcoded MinGW URL if release parsing fails.
    6. Downloads required build tools.
    7. Compiles a WinSparkle stub DLL.
    8. Installs reMarkable silently.
    9. Replaces WinSparkle.dll with the stub.

    The primary purpose is to generate and verify the replacement DLL.
    Final deployment should normally be handled separately, for example
    through PSADT or another enterprise packaging workflow.

.EXAMPLE
    .\Build-reMarkable-NoAutoUpdate.ps1

    Builds the WinSparkle stub DLL and installs reMarkable in a test environment
    so the replacement DLL can be verified before packaging.

.NOTES
    Must be run as Administrator.
#>

#region Config
$WorkDir        = "C:\Temp\reMarkable"

$RemarkableUrl  = $null

# Last verified available version on 2026-03-09.
# If this fallback is used, verify whether a newer version exists at:
#   https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/reMarkable/reMarkableCompanionApp
#   https://winstall.app/apps/reMarkable.reMarkableCompanionApp
#   https://downloads.remarkable.com/
$RemarkableFallbackUrl = "https://downloads.remarkable.com/desktop/production/win/reMarkable-3.25.0.1274-win64.exe"

$RemarkableExe  = "$WorkDir\reMarkable-installer.exe"
$InstallDir     = "C:\Program Files\reMarkable"
$StubSource     = "$WorkDir\WinSparkle_stub.c"
$StubDll        = "$WorkDir\WinSparkle.dll"

$MinGWDir       = "C:\mingw64"

# Last verified available MinGW version on 2026-03-09.
# If this fallback is used, verify whether a newer version exists at:
#   https://github.com/niXman/mingw-builds-binaries/releases/latest
#   https://github.com/niXman/mingw-builds-binaries/releases
$MinGWUrl       = "https://github.com/niXman/mingw-builds-binaries/releases/download/13.2.0-rt_v11-rev1/x86_64-13.2.0-release-posix-seh-msvcrt-rt_v11-rev1.7z"
$MinGWArchive   = "$WorkDir\mingw64.7z"

$7ZipUrl        = "https://www.7-zip.org/a/7z2600-x64.exe"
$7ZipInstaller  = "$WorkDir\7zip.exe"
#endregion

#region Functions
function Write-Step {
    param([string]$Message)
    Write-Host "`n[$([DateTime]::Now.ToString('HH:mm:ss'))] $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  OK: $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  WARN: $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  FAIL: $Message" -ForegroundColor Red
    exit 1
}

function Get-RemoteFileSize {
    param([string]$Url)
    try {
        $ProgressPreference = 'SilentlyContinue'
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing
        return [long]$response.Headers['Content-Length']
    }
    catch {
        return $null
    }
}

function Get-FileIfNeeded {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Label
    )

    $ProgressPreference = 'SilentlyContinue'
    $markerFile     = "$Destination.url"
    $remoteFileName = [System.IO.Path]::GetFileName(([Uri]$Url).LocalPath)

    if (Test-Path $Destination) {
        $localSize   = (Get-Item $Destination).Length
        $remoteSize  = Get-RemoteFileSize -Url $Url
        $markerMatch = (Test-Path $markerFile) -and ((Get-Content $markerFile -Raw).Trim() -eq $Url)

        if ($markerMatch) {
            if ($remoteSize -and $localSize -eq $remoteSize) {
                Write-OK "$Label already downloaded, URL and size match ($localSize bytes), skipping"
                return
            }
            elseif (-not $remoteSize) {
                Write-OK "$Label already downloaded, URL matches ($remoteFileName), skipping"
                return
            }
            else {
                Write-Warn "URL matches but size differs (local=$localSize, remote=$remoteSize), re-downloading..."
            }
        }
        else {
            Write-Warn "New URL detected ($remoteFileName), re-downloading..."
        }

        Remove-Item $Destination -Force
        if (Test-Path $markerFile) { Remove-Item $markerFile -Force }
    }

    Write-Host "  Downloading $Label ($remoteFileName)..." -ForegroundColor White
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    $Url | Set-Content $markerFile -Encoding UTF8
    Write-OK "Downloaded: $Destination ($((Get-Item $Destination).Length) bytes)"
}

function Get-LatestRemarkableUrlFromWingetHtml {
    Write-Step "Fetching latest reMarkable installer URL from winget-pkgs HTML..."

    try {
        $treeUrl = "https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/reMarkable/reMarkableCompanionApp"
        $response = Invoke-WebRequest -Uri $treeUrl -UseBasicParsing

        $versions = [regex]::Matches($response.Content, '>(\d+\.\d+\.\d+(?:\.\d+)?)<') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique

        if (-not $versions) {
            Write-Warn "No version folders found in winget-pkgs HTML"
            return $null
        }

        $latestVersion = $versions |
            Sort-Object { [version]$_ } |
            Select-Object -Last 1

        Write-OK "Latest manifest version: $latestVersion"

        $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/r/reMarkable/reMarkableCompanionApp/$latestVersion/reMarkable.reMarkableCompanionApp.installer.yaml"
        $yaml = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing

        if ($yaml.Content -match '(?m)^\s*InstallerUrl:\s*(\S+)\s*$') {
            Write-OK "Installer URL from winget-pkgs: $($Matches[1])"
            return $Matches[1]
        }

        Write-Warn "InstallerUrl not found in winget-pkgs YAML"
    }
    catch {
        Write-Warn ("Could not fetch from winget-pkgs HTML: " + $_.Exception.Message)
    }

    return $null
}

function Get-LatestRemarkableUrlFromWinstall {
    Write-Step "Fetching latest reMarkable installer URL from winstall.app..."

    try {
        $ProgressPreference = 'SilentlyContinue'
        $response = Invoke-WebRequest -Uri "https://winstall.app/apps/reMarkable.reMarkableCompanionApp" -UseBasicParsing

        if ($response.Content -match 'href="(https://downloads\.remarkable\.com/desktop/production/win/reMarkable-[\d\.]+-win64\.exe)"') {
            Write-OK "Installer URL from winstall.app: $($Matches[1])"
            return $Matches[1]
        }

        Write-Warn "No matching installer URL found on winstall.app"
    }
    catch {
        Write-Warn ("Could not fetch from winstall.app: " + $_.Exception.Message)
    }

    return $null
}

function Get-Latest7ZipUrl {
    Write-Step "Fetching latest 7-Zip installer URL from 7-zip.org..."

    try {
        $ProgressPreference = 'SilentlyContinue'
        $response = Invoke-WebRequest -Uri "https://www.7-zip.org/download.html" -UseBasicParsing

        if ($response.Content -match 'href="(a/7z(\d+)-x64\.exe)"') {
            $file = $Matches[1]
            Write-OK "Latest 7-Zip: $file"
            return "https://www.7-zip.org/$file"
        }

        Write-Warn "No matching 7-Zip x64 installer found"
    }
    catch {
        Write-Warn "Could not fetch 7-Zip version, using hardcoded URL"
    }

    return $null
}

function Get-LatestMinGWUrl {
    Write-Step "Fetching latest MinGW release from GitHub..."

    try {
        $ProgressPreference = 'SilentlyContinue'
        $url = "https://github.com/niXman/mingw-builds-binaries/releases/latest"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing

        $html = $response.Content
        $releaseTag = $null

        if ($html -match '<title>Release Release of ([0-9]+\.[0-9]+\.[0-9]+-rt_v[0-9]+-rev[0-9]+)') {
            $releaseTag = $Matches[1]
        }
        elseif ($html -match '/releases/tag/([0-9]+\.[0-9]+\.[0-9]+-rt_v[0-9]+-rev[0-9]+)') {
            $releaseTag = $Matches[1]
        }
        elseif ($html -match 'Release of ([0-9]+\.[0-9]+\.[0-9]+-rt_v[0-9]+-rev[0-9]+)') {
            $releaseTag = $Matches[1]
        }

        if (-not $releaseTag) {
            Write-Warn "Could not parse MinGW release tag from GitHub HTML"
            return $null
        }

        if ($releaseTag -notmatch '^([0-9]+\.[0-9]+\.[0-9]+)-rt_v([0-9]+)-rev([0-9]+)$') {
            Write-Warn "Could not parse MinGW version components from release tag: $releaseTag"
            return $null
        }

        $gccVersion = $Matches[1]
        $rtVersion  = $Matches[2]
        $revVersion = $Matches[3]

        $fileName = "x86_64-$gccVersion-release-posix-seh-msvcrt-rt_v$rtVersion-rev$revVersion.7z"
        $fullUrl  = "https://github.com/niXman/mingw-builds-binaries/releases/download/$releaseTag/$fileName"

        Write-OK "Latest MinGW release: $releaseTag"
        Write-OK "MinGW archive: $fileName"
        Write-OK "Download URL: $fullUrl"

        return $fullUrl
    }
    catch {
        Write-Warn ("Could not resolve MinGW latest release, using hardcoded URL: " + $_.Exception.Message)
    }

    return $null
}

function Get-7ZipExe {
    if (Get-Command 7z -ErrorAction SilentlyContinue) {
        Write-OK "7-Zip already in PATH"
        return "7z"
    }

    $regPath = "HKLM:\SOFTWARE\7-Zip"
    if (Test-Path $regPath) {
        $path = (Get-ItemProperty $regPath).Path + "7z.exe"
        if (Test-Path $path) {
            Write-OK "7-Zip found at $path"
            return $path
        }
    }

    Get-FileIfNeeded -Url $7ZipUrl -Destination $7ZipInstaller -Label "7-Zip"
    Start-Process -FilePath $7ZipInstaller -ArgumentList "/S" -Wait
    return "C:\Program Files\7-Zip\7z.exe"
}
#endregion

#region Preflight
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Fail "Script must be run as Administrator"
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Write-OK "Working directory: $WorkDir"
#endregion

#region Step 1 - Resolve latest URLs
$latestRemarkable = Get-LatestRemarkableUrlFromWingetHtml

if (-not $latestRemarkable) {
    Write-Warn "winget-pkgs lookup failed, trying winstall.app..."
    $latestRemarkable = Get-LatestRemarkableUrlFromWinstall
}

if ($latestRemarkable) {
    $RemarkableUrl = $latestRemarkable
}
else {
    Write-Warn "Using hardcoded reMarkable fallback version (last verified 2026-03-09)"
    $RemarkableUrl = $RemarkableFallbackUrl
}

Write-OK "Using installer: $RemarkableUrl"

$latest7Zip = Get-Latest7ZipUrl
if ($latest7Zip) { $7ZipUrl = $latest7Zip }

$latestMinGW = Get-LatestMinGWUrl
if ($latestMinGW) {
    $MinGWUrl = $latestMinGW
}
else {
    Write-Warn "Using hardcoded MinGW fallback version (last verified 2026-03-09)"
}
#endregion

#region Step 2 - Download reMarkable
Write-Step "Checking reMarkable installer..."
Get-FileIfNeeded -Url $RemarkableUrl -Destination $RemarkableExe -Label "reMarkable installer"
#endregion

#region Step 3 - Download and extract MinGW
Write-Step "Checking MinGW compiler..."

$GccExe = Get-ChildItem -Path $MinGWDir -Recurse -Filter "gcc.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "testgcc|fake" } |
    Select-Object -First 1 -ExpandProperty FullName

if ($GccExe) {
    Write-OK "gcc already present: $GccExe"
}
else {
    Get-FileIfNeeded -Url $MinGWUrl -Destination $MinGWArchive -Label "MinGW"

    $7z = Get-7ZipExe
    Write-Step "Extracting MinGW..."
    Start-Process -FilePath $7z -ArgumentList "x `"$MinGWArchive`" -o`"$MinGWDir`" -y" -Wait -NoNewWindow
    Write-OK "Extracted to $MinGWDir"

    $GccExe = Get-ChildItem -Path $MinGWDir -Recurse -Filter "gcc.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "testgcc|fake" } |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $GccExe) { Write-Fail "gcc.exe not found under $MinGWDir" }
Write-OK "Using gcc: $GccExe"
#endregion

#region Step 4 - Create stub C source
Write-Step "Creating WinSparkle stub source..."

@($StubSource, $StubDll) | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item $_ -Force
        Write-OK "Removed previous: $_"
    }
}

$stubCode = @'
#include <windows.h>

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason, LPVOID lpReserved) {
    return TRUE;
}

void __cdecl win_sparkle_check_update_with_ui(void) {}
void __cdecl win_sparkle_check_update_with_ui_and_install(void) {}
void __cdecl win_sparkle_check_update_without_ui(void) {}
void __cdecl win_sparkle_cleanup(void) {}
void __cdecl win_sparkle_clear_http_headers(void) {}
int  __cdecl win_sparkle_get_automatic_check_for_updates(void) { return 0; }
long __cdecl win_sparkle_get_last_check_time(void) { return -1; }
int  __cdecl win_sparkle_get_update_check_interval(void) { return 0; }
void __cdecl win_sparkle_init(void) {}
void __cdecl win_sparkle_set_app_build_version(const wchar_t* build) {}
void __cdecl win_sparkle_set_app_details(const wchar_t* company, const wchar_t* app, const wchar_t* version) {}
void __cdecl win_sparkle_set_appcast_url(const char* url) {}
void __cdecl win_sparkle_set_automatic_check_for_updates(int state) {}
void __cdecl win_sparkle_set_can_shutdown_callback(void* callback) {}
void __cdecl win_sparkle_set_config_methods(void* methods) {}
void __cdecl win_sparkle_set_did_find_update_callback(void* callback) {}
void __cdecl win_sparkle_set_did_not_find_update_callback(void* callback) {}
void __cdecl win_sparkle_set_dsa_pub_pem(const char* pem) {}
void __cdecl win_sparkle_set_eddsa_public_key(const char* key) {}
void __cdecl win_sparkle_set_error_callback(void* callback) {}
void __cdecl win_sparkle_set_http_header(const char* name, const char* value) {}
void __cdecl win_sparkle_set_lang(const wchar_t* lang) {}
void __cdecl win_sparkle_set_langid(unsigned short langid) {}
void __cdecl win_sparkle_set_registry_path(const wchar_t* path) {}
void __cdecl win_sparkle_set_shutdown_request_callback(void* callback) {}
void __cdecl win_sparkle_set_update_cancelled_callback(void* callback) {}
void __cdecl win_sparkle_set_update_check_interval(int interval) {}
void __cdecl win_sparkle_set_update_dismissed_callback(void* callback) {}
void __cdecl win_sparkle_set_update_postponed_callback(void* callback) {}
void __cdecl win_sparkle_set_update_skipped_callback(void* callback) {}
void __cdecl win_sparkle_set_user_run_installer_callback(void* callback) {}
'@

$stubCode | Set-Content -Path $StubSource -Encoding UTF8
Write-OK "Source file created: $StubSource"
#endregion

#region Step 5 - Compile stub DLL
Write-Step "Compiling WinSparkle stub DLL..."

$gccDir  = [System.IO.Path]::GetDirectoryName($GccExe)
$gccArgs = "-shared -o `"$StubDll`" `"$StubSource`" -Wl,--kill-at"

$proc = Start-Process -FilePath $GccExe -ArgumentList $gccArgs -Wait -NoNewWindow -WorkingDirectory $gccDir -PassThru
if ($proc.ExitCode -ne 0) { Write-Fail "gcc compilation failed with exit code $($proc.ExitCode)" }
if (-not (Test-Path $StubDll)) { Write-Fail "WinSparkle.dll was not created" }

Write-OK "Compiled: $StubDll ($((Get-Item $StubDll).Length) bytes)"
#endregion

#region Step 6 - Install reMarkable
Write-Step "Installing reMarkable silently..."

$proc = Start-Process -FilePath $RemarkableExe -ArgumentList "install --confirm-command --default-answer --accept-licenses" -Wait -PassThru

if ($proc.ExitCode -eq 0) {
    Write-OK "Installation completed successfully"
}
elseif ($proc.ExitCode -eq 1) {
    Write-Warn "Installer returned exit code 1 - may already be installed, continuing..."
}
else {
    Write-Fail "Installer failed with exit code $($proc.ExitCode)"
}

if (-not (Test-Path "$InstallDir\reMarkable.exe")) {
    Write-Fail "reMarkable.exe not found after install"
}
#endregion

#region Step 7 - Replace WinSparkle.dll
Write-Step "Replacing WinSparkle.dll..."

$originalDll = "$InstallDir\WinSparkle.dll"
$backupDll   = "$InstallDir\WinSparkle.dll.bak"

if (Test-Path $originalDll) {
    Copy-Item -Path $originalDll -Destination $backupDll -Force
    Write-OK "Original backed up to: $backupDll"
}

Copy-Item -Path $StubDll -Destination $originalDll -Force
Write-OK "Stub DLL deployed to: $originalDll"
#endregion

Write-Host "`nDone. reMarkable installed with auto-updater disabled." -ForegroundColor Green
