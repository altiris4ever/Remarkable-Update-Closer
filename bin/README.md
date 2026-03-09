Compiled WinSparkle Stub
========================

This directory contains the compiled WinSparkle.dll stub used to disable
the auto-update mechanism in the reMarkable Companion App.

The DLL is built from the source code located in:

    ../src/WinSparkle_stub.c

It exports the same WinSparkle API functions expected by reMarkable.exe
but performs no actions.
