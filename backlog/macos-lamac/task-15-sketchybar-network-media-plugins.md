# Task 15 — SketchyBar network + media plugins (wifi, tailscale, media island)

Status: todo
Scope: repo-only
Depends on: task-13
Size: M

## Objective
Wi-Fi SSID, Tailscale/VPN status, and the center "media island" — the
translations of Waybar's wifi.sh, vpn.sh, and island.sh.

## Files involved
- `stow/os-macos/sketchybar/.config/sketchybar/plugins/{wifi.sh,vpn.sh,media.sh}` (new)
- `sketchybarrc` (register; media item is the single center item, like
  Waybar's modules-center island)

## Reason
Same at-a-glance signals as Omarchy: what network, is the tailnet up, what's
playing.

## Proposed implementation
Read the Waybar originals first
(`stow/os-omarchy/waybar/.config/waybar/scripts/{wifi,vpn,island}.sh`) to
match icons/labels/states.
- wifi.sh: SSID via `ipconfig getsummary en0 | awk -F': ' '/ SSID/ {print $2}'`
  (`networksetup -getairportnetwork` is deprecated on macOS 26 — do not use).
  States: connected (SSID), no wifi, ethernet-active (check `ipconfig getifaddr`
  on the active service) — merges Waybar's wifi + ethernet modules.
- vpn.sh: `tailscale status` (CLI from Tailscale.app; probe
  `command -v tailscale || /Applications/Tailscale.app/Contents/MacOS/Tailscale`).
  States: connected / disconnected / not installed, same icon language as
  Waybar's vpn.sh. update_freq 10.
- media.sh (island): mirror island.sh's contract — playing `󰎈 artist - title`
  (truncate 56 chars), paused `󰏤`, idle empty. Source: Spotify AppleScript
  event (`com.spotify.client.PlaybackStateChanged` -> sketchybar custom event,
  as in the old rc) and `osascript -e 'tell application "Spotify" ...'` for
  metadata. System-wide Now Playing has no stable public CLI on macOS 26 —
  Spotify-only is the honest v1; note it in the file header. Screen-recording
  state from island.sh: dropped, no macOS analog.

## Safety concerns
Same plugin rules as task 14: fast, offline, read-only. AppleScript to Spotify
may prompt for Automation permission once — note in docs (task 22).

## Validation commands
```bash
shellcheck stow/os-macos/sketchybar/.config/sketchybar/plugins/{wifi,vpn,media}.sh
# On a Mac: run each standalone; toggle wifi/tailscale/Spotify and re-run.
```

## Rollback notes
Remove files + registrations.

## Acceptance criteria
On lamac: SSID shows, tailscale state correct, Spotify track appears center
when playing, empty when idle. All shellcheck-clean.
