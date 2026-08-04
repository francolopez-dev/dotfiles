# KeepAwakeAndTeamsActive.ps1
# Prevents Windows from sleeping and periodically sends an unused key (F15)
# to help maintain activity for applications like Microsoft Teams.

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Power {
    private const uint ES_CONTINUOUS = 0x80000000;
    private const uint ES_SYSTEM_REQUIRED = 0x00000001;
    private const uint ES_DISPLAY_REQUIRED = 0x00000002;

    [DllImport("kernel32.dll")]
    private static extern uint SetThreadExecutionState(uint esFlags);

    public static void KeepAwake() {
        SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
    }

    public static void Restore() {
        SetThreadExecutionState(ES_CONTINUOUS);
    }
}
"@

Add-Type -AssemblyName System.Windows.Forms

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Keep Awake + Teams Activity Script Started"
Write-Host " Press Ctrl+C to stop."
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

$lastKey = Get-Date

try {
    while ($true) {
        [Power]::KeepAwake()

        # Send F15 every 4 minutes. F15 is usually unbound, so it should not
        # interfere with normal typing or shortcuts.
        if (((Get-Date) - $lastKey).TotalSeconds -ge 240) {
            [System.Windows.Forms.SendKeys]::SendWait("{F15}")
            $lastKey = Get-Date
            Write-Host "$(Get-Date -Format 'HH:mm:ss') - Sent F15"
        }

        Start-Sleep -Seconds 30
    }
}
finally {
    [Power]::Restore()
    Write-Host "Power settings restored."
}
