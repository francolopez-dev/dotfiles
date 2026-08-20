# Omarchy 4 Migration Audit

This is the parity checklist for upgrading repo-managed Omarchy machines from
the legacy Hyprland `.conf` stack to Omarchy 4's Lua configuration.

## Active Configuration

Omarchy 4 loads these files after its defaults:

```text
stow/os-omarchy/hyprland/.config/hypr/bindings.lua
stow/os-omarchy/hyprland/.config/hypr/looknfeel.lua
stow/os-omarchy/hyprland/.config/hypr/autostart.lua
stow/profile-<hostname>-omarchy/hyprland/.config/hypr/monitors.lua
stow/profile-<hostname>-omarchy/hyprland/.config/hypr/input.lua
stow/profile-<hostname>-omarchy/hyprland/.config/hypr/profile.lua
```

The old `.conf` files remain only while a machine is still on pre-4 Omarchy.
They are not active on Omarchy 4.

## Shared Parity

| Area | Migrated behavior |
|---|---|
| Window gaps | Inner `3`, outer `6` |
| Borders | Size `2`, green active, muted inactive |
| Rounding | `8` |
| Dim/shadow/blur | Old values ported exactly |
| Animations | Old curves, speeds, and styles ported exactly |
| Terminal | Ghostty through `omarchy-launch-terminal` |
| Command shortcuts | Select/copy/paste/close/quit restored with terminal-aware actions |
| Workspaces | Old Ctrl-based 1-8 mapping plus repaired Omarchy numeric defaults |
| Quick surfaces | Quake, notes, and todo use Omarchy 4 Lua dispatcher expressions |
| Display panel | Scale and terminal text changes persist through Stow-safe wrappers |

The old Fornax monitor scale was `0.85`; the current intentional value is `1.6`
because it was selected in the Omarchy 4 Display panel. Gap values did not
change, although display scale changes their perceived physical size.

## Profile Parity

Both Fornax and Nox declare:

- VRR enabled (`misc.vrr = 1`).
- Balanced power profile after login.
- Explicit tap-to-click and the previous touchpad settings.
- The profile-specific Hypridle policy.
- Omarchy shell idle disabled through its Stay Awake state so two idle engines
  do not race.
- Display-panel-compatible monitor variables.

Fornax additionally keeps `altwin:swap_alt_win`; physical Alt acts as logical
Super and physical Super acts as logical Alt.

## Package Requirement

`hypridle` is declared in `packages/os-omarchy/pacman.txt`. Run `dotfiles
update` after upgrading a machine so the old profile idle policy becomes active.

## Verification

```bash
dotfiles update
hyprctl reload
hyprctl configerrors
scripts/validate-profiles.sh
powerprofilesctl get
hyprctl getoption misc:vrr
hyprctl getoption general:gaps_in
hyprctl getoption general:gaps_out
hyprctl getoption decoration:rounding
pgrep -a hypridle
omarchy-quake toggle
omarchy-notes toggle
omarchy-todo toggle
```

Bindings must show symbolic keys, not blank `code:N` registrations:

```bash
hyprctl binds -j | jq -r '.[] | select(.description != null) | [.key,.keycode,.description] | @tsv'
```

After Nox is upgraded and this checklist passes there, remove the legacy shared
and profile `.conf` compatibility trees.
