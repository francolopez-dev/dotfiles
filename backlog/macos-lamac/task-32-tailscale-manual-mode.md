# Task 32 — Tailscale manual-only mode (root cause + fix)

Status: closed — fix FAILED validation on 2026-07-08; superseded by task 33.
The investigation and dotfiles audit below stand; the "policy + GUI toggle"
remedy does not: live log forensics showed IPNExtension rewrites the NE
configuration on every launch (overwriting Franco's manual disable within
5 seconds) regardless of the documented policy, and on-demand relaunches
the extension at every boot. See task-33-tailscale-oss-migration.md for
the evidence table and the permanent solution.
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

## Validation matrix results (2026-07-08, second pass)

| # | Test | Result |
| --- | --- | --- |
| 1 | Disable VOD in Tailscale UI, stays disabled | PENDING Franco (GUI-only); both the documented policy and the internal marker now say "user-owned", so the revert mechanism is disarmed |
| 2 | Disconnect persists, no auto-reconnect | PASS at engine level: `WantRunning=false` survived multiple extension restarts over hours; NE session stays alive only because VOD is still TRUE in the config |
| 3 | Quit completely -> no background tunnel | FAIL as expected pre-toggle: macOS relaunches the extension in ~10s while `OnDemandEnabled: TRUE`; re-test after Test 1 |
| 4 | Reopen app -> still disconnected, VOD off | PENDING (needs Test 1 first) |
| 5 | Logout/login | PENDING Franco |
| 6 | Reboot | PENDING Franco (fold into task 28) |
| 7 | Manual connect works | PASS (`Tailscale up` connected, peers listed) |
| 8 | Manual disconnect stays down | PASS at engine level (see Test 2) |

## Durability findings (second pass)
- `VPNOnDemandIsUserConfigured` is a **documented, supported system policy**
  (tailscale.com/docs/integrations/mdm/mac): "instructs Tailscale to avoid
  modifying the on-demand configuration". Documented application for the
  App Store build: `defaults write io.tailscale.ipn.macos
  VPNOnDemandIsUserConfigured -bool true` — applied on lamac 2026-07-08 and
  added to `scripts/macos-defaults.sh` as a confirm-gated group.
- The same-named key in the group container plist is the extension's
  INTERNAL state (set during the 1.56 migration); my first-pass write there
  was the undocumented variant. Both are now true; only the documented
  domain is automated/documented for reuse.
- Tailscale app updates: both stores survive (user prefs + group container
  persist across updates; the plist itself tracks
  `ExtensionLastLaunchVersion` across versions). macOS updates: prefs and
  containers persist. Tailscale logout / tailnet switch: policies are
  device-scoped, not account-scoped — expected to persist, NOT yet
  empirically tested; re-check after the first logout.
- `tailscale syspolicy list` does not display this key (it lists Go-side
  registered policies; this one is consumed by the Swift OnDemandManager).
  Verify via `defaults read io.tailscale.ipn.macos
  VPNOnDemandIsUserConfigured` instead.

## Architecture comparison (for the manual-dial workflow)
- **App Store build (installed)**: sandboxed app + NE app extension. VOD
  auto-management neutralized by the documented policy; menu bar UI kept.
  Chosen path.
- **Standalone .pkg build (macsys)**: same Swift GUI and same
  OnDemandManager code, but a system extension instead of an app extension
  (its stale 1.50.1 sysext is still registered on lamac from a past
  install). Identical VOD behavior — migrating to it would change nothing
  for this problem.
- **Open-source `tailscaled` (brew)**: plain root LaunchDaemon + utun. No
  Network Extension, no VPN profile in System Settings, no on-demand
  framework at all; `tailscale down` persists across reboots by
  construction. Perfect manual semantics, but: no menu bar UI, sudo-owned
  daemon always running, DNS/exit-node handling via CLI only. Contingency
  if the App Store client ever regresses.

## Result
Root cause established with evidence; machine-side marker applied; docs
section added to docs/macos-personal.md; memory updated. The repo required
no code changes (audit confirmed dotfiles are not involved).
Second pass: the fix is now anchored on the DOCUMENTED policy (defaults on
io.tailscale.ipn.macos) instead of only the internal group-container
marker; macos-defaults.sh gained a confirm-gated group for it. Tests 2/7/8
pass; 1/4/5/6 pending the GUI toggle + logout/reboot by Franco; 3 will flip
from expected-fail to pass once the NE config's on-demand is actually off.
