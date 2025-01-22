# Start logging, enable for detailed logging
#Start-Transcript -Path "C:\temp\Scriptlog\remarkable_KillUpdateLog.log"

# Add the User32 class for Windows API functions
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

# Function to close dialog windows
function Close-DialogWindow {
    param (
        [string]$PartialTitle,
        [string]$ProcessName
    )

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
            }
        }

        return $true
    }

    $enumProc = [User32+EnumWindowsProc]$callback
    [User32]::EnumWindows($enumProc, [IntPtr]::Zero) | Out-Null
}

# Process monitoring loop
$ProcessName = "remarkable"
$WindowPartialTitle = "Software Update"

try {
    while ($true) {
        # Check if remarkable.exe process is running
        $remarkableProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        if ($null -ne $remarkableProcess) {
            Close-DialogWindow -PartialTitle $WindowPartialTitle -ProcessName $ProcessName
            Start-Sleep -Milliseconds 100
        } else {
            Write-Host "remarkable.exe is not running. Exiting."
            break
        }
    }
} catch {
    Write-Error "An error occurred: $_"
} finally {
    Write-Host "Script has exited."
    exit 0  # Explicitly terminate the process
}

# Stop logging
#Stop-Transcript
