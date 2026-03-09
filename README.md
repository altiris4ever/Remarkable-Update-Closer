# reMarkable Companion App – Update Control

Utilities and documentation for disabling the auto-update mechanism in the **reMarkable Companion App** in managed environments.

The reMarkable updater is built on the **WinSparkle** framework:
https://winsparkle.org

This repository contains both a **current recommended method** and an **older legacy approach**.

---

## Status

| Method               | Status  | Description                                                          |
| -------------------- | ------- | -------------------------------------------------------------------- |
| WinSparkle DLL stub  | Current | Replaces `WinSparkle.dll` with a stub to fully disable update checks |
| Update Dialog Closer | Legacy  | PowerShell script that closes update dialogs when they appear        |

The **WinSparkle stub method** is the recommended solution.

The legacy method is retained for historical reference and compatibility testing.

---

## Quick Usage

To disable the auto-update mechanism in the reMarkable Companion App:

1. Install the **reMarkable Companion App** normally
2. Replace the updater library with the stub version included in this repository

Original file location:

```
C:\Program Files\reMarkable\WinSparkle.dll
```

Replace it with:

```
bin/WinSparkle.dll
```

The application will continue functioning normally but will no longer perform update checks.

---

## Why this Exists

In enterprise environments, automatic updaters bundled with applications are often incompatible with managed deployment models.

The reMarkable updater:

* uses the **WinSparkle update framework**
* requires **administrative privileges** to install updates
* may repeatedly display update dialogs for standard users

Since enterprise users typically **do not have administrative rights**, the updater cannot complete successfully and instead becomes disruptive.

In managed environments, updates should instead be delivered through the organization's **software deployment platform**.

---

## Methods

### Recommended Method – WinSparkle Stub

This method replaces `WinSparkle.dll` with a stub implementation that exports the required functions but performs no actions.

#### Effect

* Update checks are disabled
* Update dialogs are never shown
* The application continues functioning normally

Relevant files in this repository:

```
src/WinSparkle_stub.c
bin/WinSparkle.dll
scripts/Build-reMarkable-NoAutoUpdate.ps1
```

The stub DLL exports the same WinSparkle API expected by the application, allowing it to load normally while preventing update checks.

This approach is more robust because it disables the updater itself instead of reacting to its UI.

---

### Legacy Method – Update Dialog Closer

Before the stub approach was developed, the update dialog could be suppressed using a monitoring script.

This script:

* monitors running windows
* identifies update dialogs by **window title** and **process name**
* sends a `WM_CLOSE` message to close the dialog automatically

#### Implementation details

* Uses **User32.dll** to enumerate windows
* Matches windows using `ProcessName` and partial title matching
* Can be compiled to an executable using **PS2EXE**

#### Additional features in the enhanced version

* CPU-optimized polling
* process-aware monitoring
* logging support
* improved error handling

#### Limitations

* The updater itself remains active
* The dialog may reappear if the application triggers another update check

Documentation and scripts for the legacy approach can be found in:

```
legacy/update-dialog-closer/
```

---

## Enterprise Deployment

Typical deployment workflow:

1. Install the **reMarkable Companion App** silently
2. Replace `WinSparkle.dll` with the stub version
3. Deploy updates through the organization's software distribution system

This integrates cleanly with common enterprise tooling such as:

* Omnissa Workspace ONE
* Horizon VDI environments
* PowerShell automation workflows
* PSAppDeployToolkit (PSADT)
* App Volumes
* MSI repackaging pipelines

---

## Repository Structure

```
.
├─ README.md
│
├─ bin
│   ├─ README.md
│   └─ WinSparkle.dll
│
├─ docs
│   ├─ README.md
│   └─ disable-updater-method.md
│
├─ scripts
│   ├─ README.md
│   └─ Build-reMarkable-NoAutoUpdate.ps1
│
├─ src
│   ├─ README.md
│   └─ WinSparkle_stub.c
│
└─ legacy
    └─ update-dialog-closer
        ├─ README.md
        ├─ Remarkable-Update-Closer.ps1
        └─ Remarkable-Update-Closer.concept.ps1
```

---

## References

WinSparkle project
https://winsparkle.org

WinSparkle documentation
https://github.com/vslavik/winsparkle/wiki

MinGW compiler builds
https://github.com/niXman/mingw-builds-binaries/releases

PS2EXE PowerShell compiler
https://github.com/MScholtes/PS2EXE

reMarkable Companion App winget manifest
https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/reMarkable/reMarkableCompanionApp
