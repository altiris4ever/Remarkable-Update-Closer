Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class User32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint WM_CLOSE = 0x0010; // Windows Message for closing a window
}
"@

function Close-DialogWindow {
    param (
        [string]$PartialTitle,
        [string]$ProcessName
    )

    $found = $false

    $callback = {
        param ($hWnd, $lParam)

        $titleBuilder = New-Object System.Text.StringBuilder 256
        [User32]::GetWindowText($hWnd, $titleBuilder, $titleBuilder.Capacity) | Out-Null
        $title = $titleBuilder.ToString()

        if ($title -like "*$PartialTitle*") {
            $processId = [int]0
            [User32]::GetWindowThreadProcessId($hWnd, [ref]$processId) | Out-Null

            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($process -and $process.ProcessName -eq $ProcessName) {
                [User32]::PostMessage($hWnd, [User32]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                Write-Host "Closed window with title: $title from process: $ProcessName"
                $found = $true
            }
        }

        return $true
    }

    $enumProc = [User32+EnumWindowsProc]$callback
    [User32]::EnumWindows($enumProc, [IntPtr]::Zero) | Out-Null

    return $found
}

# Monitoring with dynamic wait time
$WindowPartialTitle = "Software Update"
$TargetProcessName = "remarkable"

# Start with a short wait time
$sleepTime = 100
$maxSleepTime = 500

while ($true) {
    $found = Close-DialogWindow -PartialTitle $WindowPartialTitle -ProcessName $TargetProcessName
    if ($found) {
        # If a window was found and closed, use a short wait time
        $sleepTime = 100
    } else {
        # If no windows were found, gradually increase the wait time
        $sleepTime = [math]::Min($sleepTime * 2, $maxSleepTime)
    }

    Start-Sleep -Milliseconds $sleepTime
}
