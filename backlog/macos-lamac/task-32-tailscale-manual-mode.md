# Task 32 — Tailscale manual-only mode (root cause + fix)

Status: done (one 10-second GUI step left for Franco, see "Remaining step")
Scope: mac-local investigation + docs; repo changes are docs/backlog only
Depends on: none
Size: M

## Objective
Tailscale behaves like a traditional VPN client on lamac: installed,
available, disconnected by default, connects only on explicit user action,
stays disconnected across reboot/login.

## Root cause (supersedes the 2026-07-07 diagnosis)
The old diagnosis ("VPN profile has on-demand rules") described the symptom,
not the cause. The real mechanism, established by binary inspection, docs,
and live experiments on 2026-07-08:

1. Tailscale's macOS client is designed as an always-available overlay: the
   client "automatically configures a broad VPN On Demand policy while
   Tailscale is enabled" so the tunnel survives reboots and crashes
   (tailscale.com/docs/features/client/ios-vpn-on-demand). macOS itself
   relaunches the extension — proven: with the GUI closed and the engine
   stopped, `pkill IPNExtension` was undone by the OS within 10 seconds.
2. The extension (IPNExtension.appex, v1.98.8 App Store build
   io.tailscale.ipn.macos) contains an "OnDemandManager" with
   **VPN On-Demand persistency**: at launch it re-saves on-demand into the
   NE configuration unless its own store says the user configured VOD
   deliberately. That store is
   `~/Library/Group Containers/W5364U7YZB.group.io.tailscale.ipn.macos/Library/Preferences/W5364U7YZB.group.io.tailscale.ipn.macos.plist`,
   and on lamac it said `VPNOnDemandIsUserConfigured = false`. Result: every
   out-of-band fix (System Settings toggle, deleting the VPN configuration,
   denying permission) was reverted by the extension on its next launch —
   exactly the reported loop. Binary strings: "ondemand: Enabling VPN
   On-Demand persistency", "Won't disable VOD persistency due to
   pre-existing user configuration".
3. `tailscale down` (CLI) stops the engine but does NOT remove the on-demand
   rules or the NE session — verified: after up→down the config still shows
   `OnDemandEnabled: TRUE` and scutil reports "Connected" with the engine
   "stopped". Community reports match (tailscale/tailscale#12813, #16505).
4. No supported system policy can force VOD off: `VPNOnDemandSettings`
   only shows/hides the menu item; `AlwaysOn.Enabled` and `ReconnectAfter`
   force the OPPOSITE direction (`tailscale syspolicy list` shows no
   policies active on lamac beyond EncryptState/HardwareAttestation).

Verdict: auto-recreation is BY DESIGN (overlay-network philosophy); the
"disable doesn't stick" part is the persistency manager treating VOD as
Tailscale-managed because the user-configured marker was false — behavior
that other users report as a bug.

## Dotfiles audit (clean)
- `configure_declared_services` in scripts/dotfiles: gated on omarchy +
  systemctl; unreachable on macOS.
- `_tailscale_status` (doctor) and sketchybar `vpn.sh`: read-only `status`;
  verified `status` does not launch the extension.
- tailscale is NOT declared in any macOS package list (only os-debian apt,
  os-omarchy pacman). No LaunchAgent, login item, defaults write, or
  AeroSpace hook references Tailscale.

## Applied on lamac (2026-07-08)
```bash
defaults write "~/Library/Group Containers/W5364U7YZB.group.io.tailscale.ipn.macos/Library/Preferences/W5364U7YZB.group.io.tailscale.ipn.macos" VPNOnDemandIsUserConfigured -bool true
```
This marks VOD as user-configured so the persistency manager stops
force-re-enabling it. `TailscaleStartOnLogin` was already 0.

## Remaining step (Franco, GUI-only by design)
Tailscale menu bar icon -> Settings -> turn OFF "VPN on Demand" -> Disconnect.
Only Tailscale's own code can rewrite its NE configuration; there is no CLI
or policy path. With the marker now true, the toggle should finally stick.

## Validation matrix (after the GUI step)
```bash
scutil --nc show "Tailscale" | grep OnDemandEnabled   # FALSE
pkill IPNExtension; sleep 10; pgrep -x IPNExtension   # nothing (no relaunch)
/Applications/Tailscale.app/Contents/MacOS/Tailscale status  # stopped
# reboot, then:
scutil --nc list | grep -i tailscale                  # Disconnected
pgrep IPNExtension                                    # nothing
/Applications/Tailscale.app/Contents/MacOS/Tailscale up      # manual connect works
/Applications/Tailscale.app/Contents/MacOS/Tailscale down    # manual disconnect
```

## Contingency if the toggle re-enables again
Migrate to the open-source variant, which is architecturally incapable of
this behavior: `brew install tailscale`, `sudo tailscaled
install-system-daemon`, remove the App Store app + VPN configuration. The
OSS build is a plain root LaunchDaemon with a utun interface — no Network
Extension, no VPN profile in System Settings, no on-demand framework at
all; `tailscale down` persists across reboots. Trade-offs: no menu bar UI,
sudo for daemon install, app-store variant features (Exit Node picker UI)
move to CLI. Decide only if the App Store client regresses.

## Cleanup (optional, cosmetic)
Stale standalone-variant system extension
`io.tailscale.ipn.macsys.network-extension` 1.50.1 is still "activated
enabled" (parent app gone, process never runs, no VPN config references
it — confirmed inert). Remove someday via reinstall+delete of the
standalone app, or leave it.

## Rollback
```bash
defaults write "~/Library/Group Containers/W5364U7YZB.group.io.tailscale.ipn.macos/Library/Preferences/W5364U7YZB.group.io.tailscale.ipn.macos" VPNOnDemandIsUserConfigured -bool false
```
Re-enable "VPN on Demand" in Tailscale settings for the old always-on
behavior.

## Result
Root cause established with evidence; machine-side marker applied; docs
section added to docs/macos-personal.md; memory updated. The repo required
no code changes (audit confirmed dotfiles are not involved).
