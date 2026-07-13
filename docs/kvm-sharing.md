# KVM Sharing (Lan Mouse)

Share one keyboard and mouse between the Omarchy machines and the Mac with
[Lan Mouse](https://github.com/feschber/lan-mouse). The Omarchy machine is the
primary seat: move the cursor off its screen edge and it controls the Mac.
Sharing is peer-to-peer, so the reverse direction also works from the Mac once
fingerprints are authorized in both directions.

## Why Lan Mouse

- It is the only tool that works with Hyprland as the sending side today.
  Deskflow/Synergy/Input Leap need the `InputCapture` portal, which
  `xdg-desktop-portal-hyprland` has still not merged; Lan Mouse captures with
  the `wlr-layer-shell` protocol instead, no portal needed.
- Native macOS backends for both directions since v0.11.0, replacing the old
  waynergy + Synergy 1 setup and its raw keycode remapping.
- All traffic is DTLS-encrypted with per-machine TLS certificates; peers are
  authorized by certificate fingerprint (no open input port).
- Plain TOML config that stows per machine profile.

## Where Things Live

| Piece | Path |
| --- | --- |
| Peer config (per machine) | `stow/profile-<host>-<os>/lan-mouse/.config/lan-mouse/config.toml` |
| Omarchy user service | `stow/os-omarchy/lan-mouse/.config/systemd/user/lan-mouse.service` |
| macOS LaunchAgent | `stow/os-macos/launchagents/.../com.dotfiles.lanmouse.plist` |
| Omarchy binary (dotfiles-pinned) | `~/.local/share/dotfiles/bin/lan-mouse` |
| macOS app (dotfiles-pinned) | `/Applications/Lan Mouse.app` |
| Version pin + checksums | `scripts/dotfiles` (`_LANMOUSE_VERSION`, `_LANMOUSE_SHA256_*`) |
| TLS cert + key (never in Git) | `~/.config/lan-mouse/lan-mouse.pem` |

The binary is installed from the pinned, checksummed upstream release on
EVERY platform — deliberately not pacman/brew. Omarchy's package snapshot has
shipped 0.10.x, which predates the DTLS protocol and the `daemon` subcommand
and cannot talk to 0.11+ peers; pinning one version in the repo guarantees
all peers speak the same protocol. If a pacman `lan-mouse` is installed,
remove it so the stale GUI cannot shadow the pinned one:
`sudo pacman -Rns lan-mouse`.

`dotfiles update` does the rest: installs the pinned binary/app, loads the
service, and offers the ufw rule on Omarchy. A machine whose profile stows no
lan-mouse config is left untouched.

## Pairing A New Machine

Fingerprints authorize who may send input to a machine. The private key stays
in `~/.config/lan-mouse/lan-mouse.pem`; only the public fingerprint goes in
Git.

1. Run `dotfiles update` on the machine; the daemon generates its certificate
   on first start.
2. Read the fingerprint from the `KVM sharing` section of `dotfiles doctor`
   (or: `openssl x509 -in ~/.config/lan-mouse/lan-mouse.pem -noout
   -fingerprint -sha256 | sed 's/^.*=//' | tr 'A-F' 'a-f'`).
3. Paste it into `[authorized_fingerprints]` in the PEER machine's profile
   config, commit, and run `dotfiles update` on the peer.

Current state: both Omarchy profiles already authorize `lamac`. The Omarchy
machines' fingerprints must be added to
`stow/profile-lamac-macos/lan-mouse/.config/lan-mouse/config.toml` after their
first `dotfiles update` — until then the Mac ignores them by design.

## Moving Between Sites

lan-mouse resolves hostnames with its own DNS client, which cannot do mDNS
(`.local`) lookups (upstream issue #234), so the `ips` list is what actually
connects — it tries every entry, and unreachable ones are only a retried
warning. Two strategies, combinable:

- Per site: append the peer's LAN IP to `ips` in the profile config and
  commit once per site (mac: `ipconfig getifaddr en0`; Omarchy:
  `ip -4 -brief addr`). The current home-LAN IP of `lamac` is already seeded
  in both Omarchy profiles.
- Once: add each machine's Tailscale IP (`100.x.y.z`) — stable everywhere,
  no per-site edits. Preferred as soon as Tailscale runs on the Mac again
  (backlog task 33).

## macOS Notes

- One-time grant: System Settings -> Privacy & Security -> Accessibility ->
  enable `lan-mouse`, then `launchctl kickstart -k
  gui/$(id -u)/com.dotfiles.lanmouse`. `dotfiles update`/`doctor` warn while
  the grant is missing.
- Logs: `~/Library/Logs/dotfiles/lanmouse.{out,err}.log`.
- The bundle also ships a menu-bar GUI (open `/Applications/Lan Mouse.app`).
  Stop the managed daemon first or the port is taken:
  `launchctl bootout gui/$(id -u)/com.dotfiles.lanmouse`; re-enable with
  `dotfiles update`. The GUI saves through the stow symlink and REWRITES the
  repo config (comments stripped), so after a GUI session review `git diff`
  and commit or checkout the file. Prefer editing the TOML directly.
- Upgrades are pinned: bump `_LANMOUSE_VERSION` and ALL `_LANMOUSE_SHA256_*`
  checksums in `scripts/dotfiles`, then `dotfiles update` on every peer —
  versions must match across machines (protocol compatibility).

## Omarchy Notes

- Service: `systemctl --user status lan-mouse.service`; logs with
  `journalctl --user -u lan-mouse.service`.
- Receiving input needs `sudo ufw allow 4242/udp comment 'lan-mouse'`
  (offered automatically on first service enable). The SENDING side needs no
  open port.
- Config changes: `dotfiles apply` restarts the service.

## Clipboard Sync (KDE Connect)

lan-mouse is input-only: clipboard support is an unimplemented roadmap item
and the community PR for it was rejected (upstream #438), so the declared
packages include KDE Connect as the clipboard companion — TLS-encrypted,
packaged on both platforms (`kdeconnect` in Arch extra, `kde-connect` brew
cask), and it also brings file drops between peers.

`dotfiles update` manages the daemons on both sides: on Omarchy it enables
the stowed `kdeconnectd.service` (kdeconnectd does not start reliably under
Hyprland) and offers the ufw rules (1714:1764 tcp+udp, needed for incoming
discovery regardless of the peer's firewall state); on macOS it runs
kdeconnectd via the `com.dotfiles.kdeconnectd` LaunchAgent (the app does not
reliably respawn it). macOS KDE Connect also needs the Homebrew D-Bus session
bus; `dotfiles update` loads the `org.freedesktop.dbus-session` LaunchAgent
before loading `kdeconnectd`.

One-time pairing per machine pair:

1. Run `dotfiles update` on both machines; accept the ufw prompt on Omarchy.
2. macOS only: if the peer never appears, check System Settings -> Privacy &
   Security -> Local Network -> KDE Connect is allowed.
3. Pair from either side (macOS menu bar -> device -> Pair, or
   `kdeconnect-cli --refresh && kdeconnect-cli -a && kdeconnect-cli --pair -n
   <name>` on Omarchy) and accept on the other machine.
4. Enable the Clipboard plugin on both sides (Plugin/Device settings ->
   "Clipboard: share the clipboard between devices").

Copy on one machine, paste on the other — independent of which side lan-mouse
is currently sending input.

## Clipboard Ready Notifications

Each desktop also runs a local clipboard watcher so successful sync is visible:

- macOS: `com.dotfiles.clipboard-notify` LaunchAgent watches
  `NSPasteboard.changeCount` and sends a `Clipboard ready` notification through
  `terminal-notifier` (with an `osascript` fallback).
- Omarchy: `dotfiles-clipboard-notify.service` watches Wayland clipboard
  changes through `wl-paste --watch` and sends a `Clipboard ready` notification
  through `notify-send`.

The watcher intentionally never logs, stores, or displays clipboard contents.
It notifies on any local clipboard update, including normal local copies and
remote clipboard writes received from KDE Connect.

## Troubleshooting

- Cursor will not cross: check both daemons run, the target's
  `authorized_fingerprints` contains the sender, and the target's 4242/udp is
  reachable (`nc -uvz <host> 4242`).
- Clipboard sync broken on macOS: run `dotfiles doctor` and confirm the D-Bus
  session is loaded. If not, run `dotfiles update`. The symptom is
  `DBus session bus not found` in
  `~/Library/Logs/dotfiles/kdeconnectd.err.log`.
- No `Clipboard ready` banner: check `dotfiles status`. On Omarchy inspect
  `systemctl --user status dotfiles-clipboard-notify.service`; on macOS inspect
  `launchctl print gui/$(id -u)/com.dotfiles.clipboard-notify` and the logs in
  `~/Library/Logs/dotfiles/clipboard-notify.err.log`.
- Input stuck on the wrong machine: press the release bind
  (Left Ctrl+Shift+Meta+Alt by default, set in each config.toml).
- Wrong `position`: edit the profile config (`left`/`right`/`top`/`bottom`
  are relative to the machine whose file it is), commit, `dotfiles apply`.
- Keys behaving oddly on the Mac side were fixed upstream (modifier handling,
  key repeat); if a layout issue appears, upgrade the pin before debugging.
- Scrolling from the Mac toward Omarchy not working (buttons fine, wheel AND
  trackpad dead): root cause is HYPRLAND, not lan-mouse — it dropped scroll
  events from virtual pointers. Fixed upstream in hyprwm/Hyprland PR #15319
  (merged 2026-07-04); no released Hyprland contains it as of v0.55.4, so it
  resolves with the next Hyprland release reaching Omarchy. Nothing to change
  in lan-mouse or this repo.
- Other macOS-side issues (modifier injection quirks, Caps Lock) are tracked
  upstream in lan-mouse #450 / PR #460; bump the pin when a release ships.

## Rejected Alternatives (July 2026)

- Deskflow / Synergy 3 / Input Leap: no Hyprland server support until the
  InputCapture portal lands in `xdg-desktop-portal-hyprland`; known
  cursor-stuck bugs on Wayland.
- waynergy: client-only on Wayland, needs a Synergy server on the Mac and raw
  keycode remapping (the old painful setup).
- Logitech Options+ Flow: no Linux support at all.
