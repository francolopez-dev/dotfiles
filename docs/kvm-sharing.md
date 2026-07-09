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
- Plain TOML config that stows per machine profile, plus an official Arch
  `extra` repo package.

## Where Things Live

| Piece | Path |
| --- | --- |
| Peer config (per machine) | `stow/profile-<host>-<os>/lan-mouse/.config/lan-mouse/config.toml` |
| Omarchy user service | `stow/os-omarchy/lan-mouse/.config/systemd/user/lan-mouse.service` |
| macOS LaunchAgent | `stow/os-macos/launchagents/.../com.dotfiles.lanmouse.plist` |
| Arch package | `packages/os-omarchy/pacman.txt` (`lan-mouse`) |
| macOS app | pinned release install in `scripts/dotfiles` (`_LANMOUSE_VERSION`) |
| TLS cert + key (never in Git) | `~/.config/lan-mouse/lan-mouse.pem` |

`dotfiles update` does the rest: installs the package (pacman) or the pinned
app bundle (macOS, no Homebrew cask exists), loads the service, and offers the
ufw rule on Omarchy. A machine whose profile stows no lan-mouse config is left
untouched.

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

The client entries use mDNS names (`lamac.local`, `fornax.local`), which
resolve on any shared LAN with zero per-site config. If a site blocks mDNS, or
for cross-network use, add stable IPs (e.g. Tailscale `100.x.y.z`) to the
`ips` list in the profile config and commit — the config follows the machine
everywhere.

## macOS Notes

- One-time grant: System Settings -> Privacy & Security -> Accessibility ->
  enable `lan-mouse`, then `launchctl kickstart -k
  gui/$(id -u)/com.dotfiles.lanmouse`. `dotfiles update`/`doctor` warn while
  the grant is missing.
- Logs: `~/Library/Logs/dotfiles/lanmouse.{out,err}.log`.
- The bundle also ships a menu-bar GUI (open `/Applications/Lan Mouse.app`).
  Stop the managed daemon first or the port is taken:
  `launchctl bootout gui/$(id -u)/com.dotfiles.lanmouse`; re-enable with
  `dotfiles update`.
- Upgrades are pinned: bump `_LANMOUSE_VERSION` and both `_LANMOUSE_SHA256_*`
  checksums in `scripts/dotfiles`, then `dotfiles update`.

## Omarchy Notes

- Service: `systemctl --user status lan-mouse.service`; logs with
  `journalctl --user -u lan-mouse.service`.
- Receiving input needs `sudo ufw allow 4242/udp comment 'lan-mouse'`
  (offered automatically on first service enable). The SENDING side needs no
  open port.
- Config changes: `dotfiles apply` restarts the service.

## Troubleshooting

- Cursor will not cross: check both daemons run, the target's
  `authorized_fingerprints` contains the sender, and the target's 4242/udp is
  reachable (`nc -uvz <host> 4242`).
- Input stuck on the wrong machine: press the release bind
  (Left Ctrl+Shift+Meta+Alt by default, set in each config.toml).
- Wrong `position`: edit the profile config (`left`/`right`/`top`/`bottom`
  are relative to the machine whose file it is), commit, `dotfiles apply`.
- Keys behaving oddly on the Mac side were fixed upstream (modifier handling,
  key repeat); if a layout issue appears, upgrade the pin before debugging.

## Rejected Alternatives (July 2026)

- Deskflow / Synergy 3 / Input Leap: no Hyprland server support until the
  InputCapture portal lands in `xdg-desktop-portal-hyprland`; known
  cursor-stuck bugs on Wayland.
- waynergy: client-only on Wayland, needs a Synergy server on the Mac and raw
  keycode remapping (the old painful setup).
- Logitech Options+ Flow: no Linux support at all.
