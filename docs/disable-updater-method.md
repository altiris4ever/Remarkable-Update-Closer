How to disable the reMarkable companianapp auto-updater
==========================================

Disclaimer
----------
This method may stop working in future versions if reMarkable changes the
WinSparkle function names or implements DLL integrity checks. It has been
tested and verified on reMarkable versions 3.10.0.845 and 3.24.1.1174.

Note on enterprise use
----------------------
In enterprise environments, auto-update mechanisms from third-party vendors
should not be trusted to push software without IT approval. The reMarkable
updater also requires administrative privileges to install updates, which
standard users do not have - making auto-update non-functional and disruptive
in managed environments. By replacing WinSparkle.dll with a stub, updates
are controlled entirely through the standard software deployment process.

Background
----------
At startup, reMarkable.exe calls WinSparkle.dll to perform update checks.
By replacing WinSparkle.dll with a stub DLL that exports the same functions
but performs no actions, the update check and update popup are effectively
disabled.

Analysis
--------
To verify that the appcast URL was not hardcoded inside WinSparkle.dll, the
following PowerShell command was used to extract all URLs from the DLL:

    $bytes = [System.IO.File]::ReadAllBytes("C:\Temp\WinSparkle.dll")
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    [regex]::Matches($text, 'https?://[^\x00-\x1F\s"<>]{10,}') |
        Select-Object -ExpandProperty Value |
        Sort-Object -Unique

The output contained only Sparkle XML namespace URLs and OpenSSL references,
no appcast URL. This confirmed that the URL is passed into WinSparkle at
runtime from reMarkable.exe via win_sparkle_set_appcast_url, making a proxy
DLL the cleanest solution.

To identify which functions the stub DLL must export, CFF Explorer was used:

    1. Open WinSparkle.dll in CFF Explorer
    2. Click Export Directory in the left panel
    3. Note all function names listed - these are the functions reMarkable.exe
       imports and expects to find in WinSparkle.dll

The complete export list found was:
    win_sparkle_check_update_with_ui
    win_sparkle_check_update_with_ui_and_install
    win_sparkle_check_update_without_ui
    win_sparkle_cleanup
    win_sparkle_clear_http_headers
    win_sparkle_get_automatic_check_for_updates
    win_sparkle_get_last_check_time
    win_sparkle_get_update_check_interval
    win_sparkle_init
    win_sparkle_set_app_build_version
    win_sparkle_set_app_details
    win_sparkle_set_appcast_url
    win_sparkle_set_automatic_check_for_updates
    win_sparkle_set_can_shutdown_callback
    win_sparkle_set_config_methods
    win_sparkle_set_did_find_update_callback
    win_sparkle_set_did_not_find_update_callback
    win_sparkle_set_dsa_pub_pem
    win_sparkle_set_eddsa_public_key
    win_sparkle_set_error_callback
    win_sparkle_set_http_header
    win_sparkle_set_lang
    win_sparkle_set_langid
    win_sparkle_set_registry_path
    win_sparkle_set_shutdown_request_callback
    win_sparkle_set_update_cancelled_callback
    win_sparkle_set_update_check_interval
    win_sparkle_set_update_dismissed_callback
    win_sparkle_set_update_postponed_callback
    win_sparkle_set_update_skipped_callback
    win_sparkle_set_user_run_installer_callback


Step 1 - Download a compiler
-----------------------------
Download a MinGW build from:
https://github.com/niXman/mingw-builds-binaries/releases

Select the newest build named:
x86_64-release-posix-seh-msvcrt

Note: The posix variant must be used. The win32 variant is missing
libwinpthread-1.dll which gcc requires to run.

At the time of writing this document the following archive was used:
x86_64-13.2.0-release-posix-seh-msvcrt-rt_v11-rev1.7z


Step 2 - Extract the compiler
------------------------------
Extract the archive using 7-Zip to:
C:\mingw64\


Step 3 - Create the source file
--------------------------------
Ensure C:\Temp exists, then run the following PowerShell command to generate
the C source file:

    New-Item -ItemType Directory -Force -Path C:\Temp

    $code = @'
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
    $code | Set-Content "C:\Temp\WinSparkle_stub.c" -Encoding UTF8


Step 4 - Compile the replacement DLL
--------------------------------------
gcc must be run from its own bin directory so it can find libwinpthread-1.dll.
Run the following command in an elevated Command Prompt:

    cd C:\mingw64\x86_64-13.2.0-release-posix-seh-msvcrt-rt_v11-rev1\mingw64\bin
    gcc.exe -shared -o C:\Temp\WinSparkle.dll C:\Temp\WinSparkle_stub.c -Wl,--kill-at

Verify the file was created:

    dir C:\Temp\WinSparkle.dll

Note: If gcc fails with exit code 1 and shows a libwinpthread-1.dll error,
confirm you are using the posix variant and that you are running gcc from
its own bin directory as shown above.


Step 5 - Back up the original DLL
-----------------------------------
Before replacing anything, rename the original file:

    cd "C:\Program Files\reMarkable"
    ren WinSparkle.dll WinSparkle.dll.bak


Step 6 - Replace the DLL
--------------------------
Copy the newly compiled WinSparkle.dll to the reMarkable installation folder:

    copy C:\Temp\WinSparkle.dll "C:\Program Files\reMarkable\WinSparkle.dll"


Step 7 - Repeat after upgrades
--------------------------------
The latest available version can always be found at:
    https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/reMarkable/reMarkableCompanionApp

If a new version of the application is installed, the installer will restore
the original WinSparkle.dll. The replacement procedure must then be repeated.

In a PSADT deployment script, this is automated by adding the following
after the silent install:

    ## Replace WinSparkle.dll with stub to disable auto-update
    Copy-File -Path "$dirFiles\WinSparkle.dll" -Destination "$envProgramFiles\reMarkable\WinSparkle.dll"


Automation
----------
The entire process of downloading, compiling and deploying the stub DLL can
be automated using the companion script Build-reMarkable-NoAutoUpdate.ps1.
The script dynamically fetches the latest reMarkable installer URL from
winstall.app and the latest 7-Zip from 7-zip.org, with MinGW as a hardcoded
fallback. Must be run as Administrator.


References
----------
WinSparkle project:       https://winsparkle.org
WinSparkle registry docs: https://github.com/vslavik/winsparkle/wiki/Registry-Settings
MinGW compiler builds:    https://github.com/niXman/mingw-builds-binaries/releases
CFF Explorer:             https://ntcore.com/?page_id=388
winstall.app:             https://winstall.app/apps/reMarkable.reMarkableCompanionApp
winget manifest (latest): https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/reMarkable/reMarkableCompanionApp
