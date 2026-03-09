reMarkable WinSparkle Stub Builder
==================================

Purpose
-------
This directory contains the source and build script used to generate a stub
replacement for WinSparkle.dll used by the reMarkable Companion App.

The stub DLL exports the same WinSparkle API functions but performs no actions.
Replacing the original DLL prevents the application from performing automatic
update checks or launching the built-in updater.

This is primarily intended for controlled enterprise environments where
software updates must be deployed through a managed packaging system
(e.g. PSADT, SCCM, Intune, Workspace ONE, etc).


Files
-----

Build-reMarkable-NoAutoUpdate.ps1
    PowerShell script that automatically:

    - Resolves the latest reMarkable installer from the winget-pkgs repository
    - Falls back to winstall.app if needed
    - Falls back to a hardcoded version if both fail
    - Resolves the latest MinGW compiler release
    - Downloads required tools
    - Compiles the WinSparkle stub DLL
    - Installs reMarkable silently in a test environment
    - Replaces WinSparkle.dll to verify the stub works

WinSparkle_stub.c
    Minimal C source code implementing a no-operation version of the
    WinSparkle API expected by the reMarkable application.

WinSparkle.dll
    Precompiled stub DLL generated from WinSparkle_stub.c.
    This file can be used directly during packaging if rebuilding
    the DLL is not required.


How the stub works
------------------
At startup, reMarkable.exe loads WinSparkle.dll and calls its exported
functions to check for updates.

The stub DLL implements the same exported functions but does nothing.
Because the function signatures exist, the application loads normally
but no update check occurs.


Installation location
---------------------
The DLL replaced by this project is located at:

    C:\Program Files\reMarkable\WinSparkle.dll


Typical enterprise deployment
-----------------------------
The build script is intended only for generating and verifying the stub
DLL inside a disposable VM or packaging environment.

In production deployments the stub DLL should normally be distributed
through a packaging system such as PSADT.

Example PSADT step:

    Copy-File -Path "$dirFiles\WinSparkle.dll" `
              -Destination "$envProgramFiles\reMarkable\WinSparkle.dll"


Tested versions
---------------
Verified working with:

- reMarkable Companion App 3.24.x
- reMarkable Companion App 3.25.0


Notes
-----
If reMarkable changes the WinSparkle interface, adds integrity checks,
or replaces the update mechanism in future versions, the stub may need
to be updated.
