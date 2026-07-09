# CLAUDE.md

This repo is a Git-based personal platform for rebuilding and maintaining
machines. Git is the source of truth for system intent. Secrets and private keys
do not live in Git.

## Design Rules

- Machines are disposable.
- Stow is the symlink manager.
- Bash is the automation language.
- Vaultwarden owns interactive credentials.
- The encrypted recovery pack owns key material and infrastructure exports.
- Every managed config is a real file under `stow/`.
- No Ansible, Nix, generated config files, or templating frameworks.

## Architecture

Layers apply in strict order:

```text
stow/global
stow/os-<os>
stow/profile-<hostname>-<os>
```

OS detection returns one of `omarchy`, `debian`, `ubuntu`, or `unknown`.
Machine profile directories are derived from `hostname -s` and OS. For example,
the work Lenovo named `fornax` on Omarchy uses:

```text
stow/profile-fornax-omarchy/
packages/profile-fornax-omarchy/pacman.txt
packages/profile-fornax-omarchy/aur.txt
```

If the profile directory does not exist, only `global` and `os-<os>` apply.

## Stow Layout

- `stow/global/`: universal shell, git, ssh, tmux, zsh, bash, Ghostty, and
  Alacritty config.
- `stow/os-omarchy/`: shared Omarchy desktop config such as Hyprland, Waybar,
  Atuin, Neovim, Yazi, Satty, themes, and scripts. Omarchy-owned app launcher
  defaults are not managed here.
- `stow/os-debian/`: Debian/Ubuntu server essentials.
- `stow/profile-<hostname>-<os>/`: machine-specific overrides such as monitors,
  autostart, idle, and lock config.

For Hyprland, keep shared keybindings and look/feel in `stow/os-omarchy/`.
Monitor config must live in the profile layer:

```text
stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/20-monitors.conf
```

## Package Lists

Package declarations concatenate in the same order as stow layers:

```text
packages/global/<source>.txt
packages/os-<os>/<source>.txt
packages/profile-<hostname>-<os>/<source>.txt
```

For Omarchy, `pacman.txt` installs first with pacman and `aur.txt` installs
second with paru. Do not put official repo packages in `aur.txt`. For
Debian/Ubuntu, use `apt.txt`. One package per line. Comments and blank lines
are allowed.

Package policy is project-wide: always prefer prebuilt binaries. Compilation is
the last resort. Preference order is official pacman repository, official binary
package, binary AUR package (`*-bin`), then source build only when unavoidable.
When a package exists as `foo`, `foo-bin`, and `foo-git`, declare `foo` in
`pacman.txt` if it is in the official repositories; otherwise declare `foo-bin`
in `aur.txt`. Do not declare `foo-git` or other source-built AUR packages unless
there is no maintained binary equivalent and the exception is documented in the
validation allowlist.

Binary AUR helpers can still be incompatible with current Arch libraries. For
example, `paru-bin` may lag pacman/libalpm and require an older `libalpm.so`.
In that case, bootstrap must report the incompatibility honestly and build
source `paru` as the fallback; never symlink libalpm, downgrade pacman, or switch
to yay. AUR packages declared in this repo's active package lists are trusted
inputs and may be installed non-interactively during bootstrap with paru
`--noconfirm --skipreview`. Do not use that trusted mode for arbitrary user input.

## Commands

Useful checks after edits:

```bash
shellcheck -x scripts/dotfiles scripts/bootstrap.sh scripts/lib/*.sh
scripts/dotfiles status
scripts/dotfiles apply --dry-run
```

Daily use:

```bash
dotfiles status
dotfiles update
dotfiles apply
```

## Where To Edit

- Global Git config: `stow/global/git/.gitconfig`.
- Global Git ignore: `stow/global/git/.gitignore_global`.
- Ghostty: `stow/global/ghostty/.config/ghostty/config`.
- Alacritty: `stow/global/alacritty/.config/alacritty/alacritty.toml`.
- Atuin: `stow/os-omarchy/atuin/.config/atuin/config.toml`.
- Omarchy monitor scale: profile `20-monitors.conf`, never the OS layer.
- KVM sharing (lan-mouse) peers/positions: profile
  `lan-mouse/.config/lan-mouse/config.toml`; workflow in `docs/kvm-sharing.md`.

## Safety

- Never commit secrets, private keys, local env files, recovery packs, or logs.
- Do not edit Omarchy source under `~/.local/share/omarchy/`; keep user config
  under `~/.config/` via stow-managed files.
- Do not silently overwrite local files during interactive operations.
