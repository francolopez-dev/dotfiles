# macOS First-Time Setup

This is the rebuild path for a fresh personal Mac. Homebrew is the only manual
package prerequisite; bootstrap will not install Homebrew for you.

## 1. Install Homebrew

Install from:

```text
https://brew.sh
```

Then open a new terminal so `/opt/homebrew/bin` is available.

## 2. Run Bootstrap

Remote bootstrap:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh)"
```

Or clone first:

```bash
git clone https://github.com/jfrancolopez/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Bootstrap installs prerequisites, shell UX, declared Homebrew packages, and
stows the active layers.

## 3. Rename The Machine

If this is the personal Mac, set the hostname to `lamac` so the profile layer is
`profile-lamac-macos`:

```bash
sudo scutil --set ComputerName lamac
sudo scutil --set HostName lamac
sudo scutil --set LocalHostName lamac
```

Verify:

```bash
hostname -s
dotfiles status
```

## 4. Login Round

Open Tailscale.app and log in.

Sync shell history:

```bash
atuin login
atuin sync
```

Set up GitHub SSH:

```bash
dotfiles git setup-ssh
```

## 5. Services

Start the managed UI services:

```bash
brew services start felixkratz/formulae/borders
brew services start felixkratz/formulae/sketchybar
```

Wallpaper rotation is opt-in on macOS:

```bash
cp ~/.local/share/dotfiles/com.dotfiles.wallpaper.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.dotfiles.wallpaper.plist
```

## 6. Permissions

Expected first-run prompts:

- AeroSpace: Accessibility.
- Rectangle: Accessibility.
- SketchyBar calling Spotify AppleScript: Automation.
- Spotify: allow Automation when prompted by SketchyBar/media plugin.

Grant these in System Settings when prompted.

## 7. Validate

```bash
dotfiles status
dotfiles doctor
scripts/macos-defaults.sh --dry-run
```

If Stow reports legacy conflicts from an older flat layout, back them up through
the conflict wizard before applying the new layered layout.
