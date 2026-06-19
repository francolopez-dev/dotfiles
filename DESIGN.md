# Design Principles

This platform should feel boring, legible, and safe on a fresh machine.

## Product Shape

- `dotfiles` is the user interface.
- Scripts are implementation details.
- Git is the source of truth for intent, not secrets.
- New-machine onboarding should be step-by-step and repeatable.
- Daily use should be a small command set: `update`, `doctor`, `profile`,
  `recovery`, and `sync`.

## Desktop Direction

- Terminal-first.
- Minimal, durable Omarchy desktop layer.
- Prefer Hyprland, Waybar, WezTerm, and Rofi changes that survive updates.
- Do not create windows during normal validation.
- Keep machine-specific display and hardware details out of shared desktop files.

## Safety Rules

- No private keys in Git.
- No plaintext Recovery Pack contents on persistent disk.
- No auto-login to GitHub, Tailscale, Atuin, or password stores.
- No default private-key reuse across all machines.
- No destructive update mode without explicit confirmation.

## Documentation Shape

- `README.md` is quick start and navigation.
- `docs/first-time-system.md` is the new-machine path.
- Topic docs own details.
- Historical plans can remain, but should not be required for daily operation.
