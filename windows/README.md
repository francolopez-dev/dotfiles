# Windows Scripts

Manual Windows helpers live here. These scripts are not automated by bootstrap,
stow, or `dotfiles update`; copy or download only the script you want to run.

## Keep Awake And Teams Active

`scripts/KeepAwakeAndTeamsActive.ps1` prevents Windows sleep/display timeout and
sends `F15` every 4 minutes while it is running. Press `Ctrl+C` in the terminal
to stop it and restore normal power management.

Run directly from a cloned checkout:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "$HOME\dotfiles\windows\scripts\KeepAwakeAndTeamsActive.ps1"
```

Or copy it to `C:\Scripts` first:

```powershell
New-Item -ItemType Directory -Force C:\Scripts
Copy-Item "$HOME\dotfiles\windows\scripts\KeepAwakeAndTeamsActive.ps1" C:\Scripts\
powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\KeepAwakeAndTeamsActive.ps1"
```

If you prefer not to use `-ExecutionPolicy Bypass` every time, set a user-level
policy once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
C:\Scripts\KeepAwakeAndTeamsActive.ps1
```
