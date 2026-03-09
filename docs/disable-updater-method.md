# How to Disable the reMarkable Companion App Auto-Updater

---

# Disclaimer

This method may stop working in future versions if reMarkable changes the
WinSparkle function names, modifies how the updater is loaded, or implements
DLL integrity checks.

Tested versions:

* 3.10.0.845
* 3.24.1.1174

---

# Note on Enterprise Use

In enterprise environments, auto-update mechanisms from third-party vendors
should not push software without IT approval.

The reMarkable updater requires administrative privileges to install updates.
Standard users normally do not have these privileges, which makes the
auto-update mechanism non-functional while still generating update dialogs.

By replacing **WinSparkle.dll** with a stub implementation, update control
can instead be handled entirely through the organization's software
deployment process.

---

# Background

At startup the reMarkable Companion App loads:

```
C:\Program Files\reMarkable\WinSparkle.dll
```

The application then calls WinSparkle functions to initialize the updater
and check for updates.

By replacing **WinSparkle.dll** with a stub DLL that exports the same
functions but performs no actions, update checks and update dialogs are
effectively disabled.

---

# Binary Analysis

To verify that the update feed URL was not hardcoded inside the WinSparkle
library, the original DLL shipped with the application was inspected.

File analyzed:

```
C:\Program Files\reMarkable\WinSparkle.dll
```

The following PowerShell was used to extract URLs from the binary:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("C:\Program Files\reMarkable\WinSparkle.dll")
$text = [System.Text.Encoding]::UTF8.GetString($bytes)

[regex]::Matches($text, 'https?://[^\x00-\x1F\s"<>]{10,}') |
    Select-Object -ExpandProperty Value |
    Sort-Object -Unique
```

The output contained only:

* Sparkle XML namespace references
* W3C XML namespace references
* an OpenSSL documentation link

No vendor update feed or appcast URL was found inside the DLL.

This confirms that the update feed URL is supplied dynamically by
`reMarkable.exe`, most likely through the WinSparkle API function:

```
win_sparkle_set_appcast_url
```

Because of this, replacing the DLL with a stub implementation is the
cleanest way to disable the updater.

---

# Export Analysis

The original DLL was inspected using **CFF Explorer**.

Steps:

1. Open `WinSparkle.dll` in CFF Explorer
2. Select **Export Directory**
3. Record the exported function names

File inspected:

```
C:\Program Files\reMarkable\WinSparkle.dll
```

The following exports were identified:

```
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
```

The stub DLL used in this repository exports the same function names so the
application can load it normally.

---

# Step 1 — Download a Compiler

Download a MinGW build from:

https://github.com/niXman/mingw-builds-binaries/releases

Select the newest build named:

```
x86_64-release-posix-seh-msvcrt
```

Important:

The **posix** variant must be used.
The **win32** variant does not include `libwinpthread-1.dll`, which `gcc`
requires to run.

Example version used during testing:

```
x86_64-13.2.0-release-posix-seh-msvcrt-rt_v11-rev1.7z
```

---

# Step 2 — Extract the Compiler

Extract the archive using 7-Zip to:

```
C:\mingw64\
```

---

# Step 3 — Create the Source File

Ensure the temporary directory exists:

```
New-Item -ItemType Directory -Force -Path C:\Temp
```

Then create the source file:

```powershell
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
void __cdecl win_sparkle_set_app_details(const wchar_t* company,const wchar_t* app,const wchar_t* version) {}
void __cdecl win_sparkle_set_appcast_url(const char* url) {}
void __cdecl win_sparkle_set_automatic_check_for_updates(int state) {}
void __cdecl win_sparkle_set_can_shutdown_callback(void* callback) {}
void __cdecl win_sparkle_set_config_methods(void* methods) {}
void __cdecl win_sparkle_set_did_find_update_callback(void* callback) {}
void __cdecl win_sparkle_set_did_not_find_update_callback(void* callback) {}
void __cdecl win_sparkle_set_dsa_pub_pem(const char* pem) {}
void __cdecl win_sparkle_set_eddsa_public_key(const char* key) {}
void __cdecl win_sparkle_set_error_callback(void* callback) {}
void __cdecl win_sparkle_set_http_header(const char* name,const char* value) {}
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
```

---

# Step 4 — Compile the Replacement DLL

Run from an elevated command prompt:

```
cd C:\mingw64\...\bin
gcc.exe -shared -o C:\Temp\WinSparkle.dll C:\Temp\WinSparkle_stub.c -Wl,--kill-at
```

Verify:

```
dir C:\Temp\WinSparkle.dll
```

---

# Step 5 — Back Up the Original DLL

```
cd "C:\Program Files\reMarkable"
ren WinSparkle.dll WinSparkle.dll.bak
```

---

# Step 6 — Replace the DLL

```
copy C:\Temp\WinSparkle.dll "C:\Program Files\reMarkable\WinSparkle.dll"
```

---

# Step 7 — Repeat After Upgrades

The latest version of the application can be found here:

https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/reMarkable/reMarkableCompanionApp

If the application is upgraded, the installer will restore the original
WinSparkle.dll and the replacement must be applied again.

---

# PSADT Deployment Example

In a PSADT deployment script the replacement can be automated:

```
## Replace WinSparkle.dll with stub to disable auto-update
Copy-File -Path "$dirFiles\WinSparkle.dll" -Destination "$envProgramFiles\reMarkable\WinSparkle.dll"
```

---

# Automation

The full process can be automated using the companion script:

```
Build-reMarkable-NoAutoUpdate.ps1
```

The script downloads required tools, compiles the stub DLL and deploys the
replacement automatically.

Administrator privileges are required.

---

# References

WinSparkle project
https://winsparkle.org

WinSparkle registry documentation
https://github.com/vslavik/winsparkle/wiki/Registry-Settings

MinGW compiler builds
https://github.com/niXman/mingw-builds-binaries/releases

CFF Explorer
https://ntcore.com/?page_id=388

winstall.app
https://winstall.app/apps/reMarkable.reMarkableCompanionApp

winget manifest
https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/reMarkable/reMarkableCompanionApp
