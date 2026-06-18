# Extending the platform — "how do I add X?"

This is the one go-to cheatsheet. Each change is a **one-place, obvious edit**.
The three-tier stow model resolves dotfiles as
`stow-base (global) + stow-os-base (per-OS) + profile STOW_PACKAGES`.

## Run things via `dotfiles`
Use the unified `dotfiles` CLI for day-to-day operations:

```bash
dotfiles update
dotfiles status
dotfiles doctor
dotfiles profile show
dotfiles recovery build
dotfiles sync status
```

`curl | bash` and root `./bootstrap.sh` remain installer/recovery internals.
They should keep working, but normal workflows should not require remembering
script paths.

## Add a CLI subcommand
Add one `cmd_<name>()` function in `stow/scripts/bin/dotfiles`, then add the
dispatch case and help text in that same file. Keep the function thin: parse
CLI flags, fill in active profile/OS when needed, and call the existing script
that owns the real behavior. Avoid adding standalone `dotfiles-*` commands.

## Add an app
Add the package name to a `packages/<group>/<manager>.txt` list
(`pacman.txt`, `aur.txt`, `brew.txt`, `brew-cask.txt`, `apt.txt`). If it needs a
brand-new group, create `packages/<group>/` and add the group to the relevant
profiles' `PACKAGE_GROUPS=(…)`.

## Add a global alias / shell tweak
Edit `stow/shell` (or `stow/zsh` / `stow/bash`). It is in `profiles/stow-base`,
so it applies to **every** profile and OS automatically — including `minimal`.

## Add / change an OS keyboard shortcut or desktop config
Edit `stow/hypr` (omarchy) or `stow/aerospace` (macOS). These ship via
`profiles/stow-os-base`, so the change applies to **all that-OS profiles**
automatically. No profile edits needed.

## Add a profile-only dotfile
Add the stow package to that profile's `STOW_PACKAGES=(…)` in
`profiles/<profile>.conf`. Use this only for genuinely profile-specific config;
shared dotfiles belong in `stow-base`.

## Add a sync agent
Add one `case` branch in `scripts/setup-syncing.sh` and list the agent in the
profile's `SYNC=(…)` array. Allowed today: `tailscale`, `syncthing`, `atuin`.

## Add a service
Add it to the profile's `SERVICES=(…)`. If the unit name is non-standard, map it
in `scripts/enable-services.sh` (`system_unit_for` / `user_unit_for`).

## Add a new profile
Create `profiles/<name>.conf` with `PACKAGE_GROUPS`, optional `STOW_PACKAGES`,
`SERVICES`, optional `SYNC`. Add it to `profile_os()` in
`scripts/validate-profiles.sh` and the wizard list, then run
`scripts/validate-profiles.sh`.

---

## Future improvements (intentionally not built yet)
- Per-host overrides (a `hosts/<hostname>` tier above profiles).
- Secret-aware sync automation (auto-login for Tailscale/Atuin via secrets store).
- Firefox sync strategy.
- VM / Omarchy postinstall hooks.
- Developer-workstation bootstrap variant.
