# macOS Personal Setup

## Layer Map

For the personal Mac named `lamac`, the active layers are:

```text
stow/global
stow/os-macos
stow/profile-lamac-macos
```

Package declarations are parallel:

```text
packages/global/{brew,cask}.txt
packages/os-macos/{brew,cask}.txt
packages/profile-lamac-macos/{brew,cask}.txt
```

Formulae go in `brew.txt`; GUI apps and fonts go in `cask.txt`.

## Terminal

Ghostty is the managed terminal on macOS and the standard target across the
personal environments. Edit the shared config in:

```text
stow/global/ghostty/.config/ghostty/config
```

The lamac-specific hook is:

```text
stow/profile-lamac-macos/ghostty/.config/ghostty/profile-overrides
```

Kitty may remain installed but is unmanaged. Alacritty's global config remains
tracked for non-macOS use, but Alacritty is not declared for managed Mac
installation. Removed legacy WezTerm config should not be restored.

## Window Management

AeroSpace owns tiling and workspaces. Edit it here:

```text
stow/os-macos/aerospace/.config/aerospace/aerospace.toml
```

Rectangle stays for ad-hoc snapping of floating windows. Keep its shortcuts
disjoint from AeroSpace shortcuts.

Borders is managed here:

```text
stow/os-macos/borders/.config/borders/bordersrc
```

SketchyBar is managed here:

```text
stow/os-macos/sketchybar/.config/sketchybar/
```

## Raycast

Raycast is installed as a cask and remains the launcher/productivity surface.
Raycast data, extensions, and account state are not committed to this repo.

## Wallpapers

Shared wallpapers live in Git under:

```text
stow/global/wallpapers/.local/share/wallpapers/shared/
```

Private local wallpapers live outside Git on every OS:

```text
~/Pictures/local-wallpapers/
```

Use:

```bash
dotfiles wallpaper status
dotfiles wallpaper rotate
dotfiles wallpaper open-local
```

macOS uses `desktoppr` when available, with an AppleScript fallback. The
LaunchAgent scheduler is opt-in; see `docs/wallpapers.md`.

## Tailscale (manual-only)

Tailscale.app (App Store build) is used as a traditional dial-up VPN:
disconnected by default, connected only on explicit action.

By design the client arms a broad "VPN On Demand" policy so macOS itself
relaunches the tunnel after reboots and crashes. To keep it manual:

- The documented system policy
  (`defaults write io.tailscale.ipn.macos VPNOnDemandIsUserConfigured -bool true`,
  see tailscale.com/docs/integrations/mdm/mac) must be set, otherwise the
  client re-enables on-demand on every extension launch and undoes System
  Settings changes and profile deletions. `scripts/macos-defaults.sh` offers
  this as a confirm-gated group. The extension keeps an internal marker with
  the same name in its group container
  (`~/Library/Group Containers/W5364U7YZB.group.io.tailscale.ipn.macos/Library/Preferences/`);
  that one is an implementation detail — do not automate it.
- "VPN on Demand" must be OFF in Tailscale's own Settings window (only
  Tailscale's code can rewrite its VPN configuration; there is no CLI or
  policy path).
- "Start Tailscale on login" stays off (`TailscaleStartOnLogin = 0`).

Connect/disconnect manually via the menu bar app or:

```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale up
/Applications/Tailscale.app/Contents/MacOS/Tailscale down
```

Verify the state that macOS acts on with
`scutil --nc show "Tailscale" | grep OnDemandEnabled` — FALSE means the OS
will not resurrect the tunnel. Full history, evidence, and the
open-source-variant contingency live in
`backlog/macos-lamac/task-32-tailscale-manual-mode.md`.

## AI Tooling

Ollama.app owns the CLI and models on macOS. `~/.ollama` is local state and is
never committed. LM Studio is optional and unmanaged unless a future task
declares it explicitly.

## Not Automated

These stay manual or app-owned:

- System defaults beyond the reviewed table below.
- Keychain and iCloud state.
- Mac App Store app ownership.
- VS Code settings, which Settings Sync owns.
- Browser profiles.
- Raycast and Keyboard Maestro data.
- Local/private wallpaper folders.

## Notable Defaults

These defaults are documented here and can be applied selectively with:

```bash
scripts/macos-defaults.sh --dry-run
scripts/macos-defaults.sh
```

The script is never called by bootstrap, update, or apply.

| Setting | Apply command | Revert |
| --- | --- | --- |
| Dock autohide | `defaults write com.apple.dock autohide -bool true; killall Dock` | `defaults delete com.apple.dock autohide; killall Dock` |
| Dock left orientation | `defaults write com.apple.dock orientation left; killall Dock` | `defaults delete com.apple.dock orientation; killall Dock` |
| Dock tile size 47 | `defaults write com.apple.dock tilesize -int 47; killall Dock` | `defaults delete com.apple.dock tilesize; killall Dock` |
| Finder show hidden files | `defaults write com.apple.finder AppleShowAllFiles -bool true; killall Finder` | `defaults delete com.apple.finder AppleShowAllFiles; killall Finder` |
| Show all file extensions | `defaults write -g AppleShowAllExtensions -bool true; killall Finder` | `defaults delete -g AppleShowAllExtensions; killall Finder` |
| Tap to click | `defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true` | `defaults delete com.apple.AppleMultitouchTrackpad Clicking` |
| Menu bar auto-hide (SketchyBar is primary) | `defaults write -g _HIHideMenuBar -bool true; defaults write -g AppleMenuBarVisibleInFullscreen -bool false` | `defaults write -g _HIHideMenuBar -bool false` then re-enable in System Settings > Menu Bar |
| Key repeat fast | Documented only: `defaults write -g KeyRepeat -int 2` | `defaults delete -g KeyRepeat` |
| Initial key repeat | Documented only: `defaults write -g InitialKeyRepeat -int 15` | `defaults delete -g InitialKeyRepeat` |
| Disable press-and-hold accents | Documented only: `defaults write -g ApplePressAndHoldEnabled -bool false` | `defaults delete -g ApplePressAndHoldEnabled` |
