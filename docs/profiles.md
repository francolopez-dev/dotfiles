# Profiles

Profiles declare machine intent: packages, stow packages, services, sync agents,
and optional desktop metadata.

The active profile is saved per machine at:

```text
~/.config/dotfiles/profile
```

## Supported Profiles

| Profile | OS | Purpose |
|---------|----|---------|
| `desktop-personal-omarchy` | Omarchy | Personal desktop |
| `desktop-work-omarchy` | Omarchy | Work desktop |
| `laptop-personal-omarchy` | Omarchy | Personal laptop |
| `laptop-work-omarchy` | Omarchy | Work laptop |
| `personal-macos` | macOS | Personal Mac |
| `work-macos` | macOS | Work Mac |
| `server-debian` | Debian | Personal server |
| `server-ubuntu` | Ubuntu | Work server |
| `minimal` | Any supported OS | Minimal bootstrap |

## Profile Files

Profiles live in:

```text
profiles/*.conf
```

Example:

```sh
PACKAGE_GROUPS=(common desktop personal)
STOW_PACKAGES=(nvim btop wezterm recovery-pack)
SERVICES=(tailscale)
SYNC=(tailscale atuin)
```

## Package Groups

Packages are grouped by purpose and package manager:

```text
packages/<group>/{pacman.txt,aur.txt,brew.txt,brew-cask.txt,apt.txt}
```

Current groups include:

- `common`
- `desktop`
- `server`
- `personal`
- `work`
- `gaming`
- `virtualization`

## Stow Layers

Dotfiles resolve in three layers:

| Layer | File | Scope |
|-------|------|-------|
| Global base | `profiles/stow-base` | Every profile and OS |
| OS base | `profiles/stow-os-base` | Every profile on that OS |
| Profile extras | `STOW_PACKAGES` | One profile |

The effective list is:

```text
stow-base + stow-os-base + STOW_PACKAGES
```

Packages are deduplicated in order. OS allow-lists in `profiles/stow-os.map`
still apply.

## First-Time Selection

On first run, or when `--first-time` is passed, bootstrap runs the OS-aware
profile wizard:

```bash
./bootstrap.sh --first-time
```

The wizard filters profiles by detected OS and orders Omarchy choices based on
laptop or desktop chassis when available.

## Common Commands

```bash
dotfiles profile show
dotfiles profile select
dotfiles profile reconfigure
dotfiles profile validate
```

Validate all profiles manually:

```bash
scripts/validate-profiles.sh
```

## Adding Things

- Add an app by editing `packages/<group>/<manager>.txt`.
- Add a shared shell tweak in `stow/shell`, `stow/zsh`, or `stow/bash`.
- Add an Omarchy shortcut or desktop setting in `stow/hypr`, `stow/waybar`, or
  `stow/rofi`.
- Add a profile-only dotfile by adding its stow package to `STOW_PACKAGES`.

See `docs/extending.md` for the detailed cheatsheet.
