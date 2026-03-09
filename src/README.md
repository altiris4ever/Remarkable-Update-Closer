WinSparkle Stub Source
======================

This directory contains the source code used to build the stub replacement
for WinSparkle.dll used by the reMarkable Companion App.

Purpose
-------
The reMarkable desktop application uses WinSparkle.dll to perform automatic
update checks. In managed environments this behavior is undesirable because
software updates should be deployed through an approved packaging system.

The stub DLL implements the same exported WinSparkle API functions but
performs no actions. Because the expected symbols exist, the application
loads normally while the update mechanism becomes inactive.

Source file
-----------
WinSparkle_stub.c

This file contains a minimal implementation of all exported WinSparkle
functions required by reMarkable.exe.

Build
-----
The stub DLL can be compiled using MinGW:

    gcc -shared -o WinSparkle.dll WinSparkle_stub.c -Wl,--kill-at

A build script that automatically downloads the required tools and builds
the DLL is located in:

    ../scripts/Build-reMarkable-NoAutoUpdate.ps1

Result
------
The compiled DLL can replace the original file located at:

    C:\Program Files\reMarkable\WinSparkle.dll

When replaced, the application will start normally but will no longer
check for updates.
