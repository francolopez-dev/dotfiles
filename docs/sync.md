# Sync Setup

Phase 3A sync is intentionally non-destructive. Bootstrap can install packages
and enable declared services, but it does not log in to Tailscale, Atuin, or
Syncthing and it does not create synced folders automatically.

For `laptop-work-omarchy` the active sync agents are:

```sh
SERVICES=(tailscale)
SYNC=(tailscale atuin)
```

## Commands

```bash
dotfiles sync status
dotfiles sync setup
dotfiles sync doctor
```

## Tailscale

Profiles declare `tailscale` as a friendly service name. On Omarchy it maps to
`tailscaled.service`.

Bootstrap installs/enables the service, but does not join the tailnet. After
setup, run exactly:

```bash
sudo tailscale up
```

Do not back up or restore `/var/lib/tailscale`; rejoin machines after recovery.

## Atuin

Atuin is installed from the normal package list where available. For Omarchy it
is in `packages/common/pacman.txt`.

`dotfiles sync setup` detects:

- missing Atuin
- installed but not logged in
- logged in and syncing

Login/import is manual for now:

```bash
atuin login
atuin import auto
atuin sync
```

No self-hosted Atuin server is configured in Phase 3A.

## Syncthing

Syncthing is not enabled for `laptop-work-omarchy` right now. Add it only to a
profile that should run it, then include the package in that profile's package
groups and add `syncthing` to `SYNC=()` and usually `SERVICES=()`.

Safe starter folders, configured manually in the Syncthing UI:

```text
Documents
Projects
Notes
Wallpapers
```

Do not auto-create or auto-share folders from bootstrap. A NAS hub can be added
later as a separate design.
