# Minimal Server Bootstrap (Debian/Ubuntu Headless)

Bring the normal terminal experience — zsh + p10k prompt, shared aliases,
tmux + `tdl` layouts, lightweight vi/nano, the `dotfiles` CLI — to headless Debian/Ubuntu
machines: personal servers, work servers, VPS, Raspberry Pi/mini PCs, and
temporary admin shells. No GUI, no desktop packages, no Omarchy config.

This is not a separate mode. The layer system already does the right thing on
Debian/Ubuntu: only `stow/global` and `stow/os-debian` apply, and only
`packages/global/apt.txt` + `packages/os-debian/apt.txt` install. `--minimal`
is an explicit guard so a server runbook cannot be pasted onto a desktop
machine — on Omarchy/macOS it refuses to run; on Debian/Ubuntu it behaves
exactly like the plain bootstrap.

## Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --minimal
exec zsh
dotfiles status
```

What it does, in order:

1. Installs prerequisites with apt: `git stow zsh curl bash ca-certificates`.
2. Clones the repo to `~/dotfiles` and links `~/.local/bin/dotfiles`.
3. Installs Oh My Zsh, zsh-autosuggestions, zsh-syntax-highlighting, and
   Powerlevel10k (git clones into `$HOME`; no system changes).
4. Stows shell config first (bash, shell, zsh, scripts), then runs
   `dotfiles update`: declared apt packages + all applicable stow layers.

Existing files are never silently overwritten; conflicting files are backed up
under `~/.dotfiles-backup/YYYY-MM-DD-HHMMSS/`.

Daily use is the same as everywhere else:

```bash
dotfiles status
dotfiles update
dotfiles apply
```

## Migrating A Host From The Old Flat Layout

Machines bootstrapped before the layer system (e.g. domum-core) have a
`~/dotfiles` checkout with flat packages (`stow/shell`, `stow/git`,
`stow/ssh`, `stow/tmux`) and home symlinks pointing at those paths. Old stow
folded directories, so `~/.ssh` is a **symlink into the repo** and private
keys / `authorized_keys` sit untracked inside the checkout. Two hard rules:

- Never `rm -rf ~/dotfiles` on such a host before checking `ls -la ~/.ssh` —
  if it is a symlink into the repo, deleting the checkout deletes your keys
  and locks you out.
- Never `git stash -u` / `git clean` there — untracked files include the keys.

Migration, from a working terminal (Alacritty, or Ghostty after the
troubleshooting section below):

```bash
# 1. See what you have. Expect symlinks into ~/dotfiles/stow/... and a dirty repo.
readlink -f ~/.zshrc ~/.gitconfig ~/.ssh ~/.tmux.conf
git -C ~/dotfiles status --short --branch

# 2. Run the new bootstrap. It rescues ~/.ssh FIRST (converts it to a real
#    700 directory, moves key material out of the repo, deletes nothing),
#    then stops if the checkout has local changes.
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --minimal

# 3. If it stopped on local changes: review, stash (tracked only), rerun.
git -C ~/dotfiles diff
git -C ~/dotfiles stash push -m "pre-layer-migration"
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --minimal

# 4. Verify BEFORE closing this session: real ~/.ssh, a fresh login, sane links.
ls -la ~/.ssh            # real directory, mode 700, keys present
ssh <this-host> true     # from your laptop, in a NEW terminal
dotfiles status && dotfiles doctor
```

What the pull does to the old home symlinks: the old repo paths disappear, so
`~/.zshrc`, `~/.gitconfig`, `~/.tmux.conf` dangle for a moment; the stow step
detects them as conflicts, moves them into `~/.dotfiles-backup/<timestamp>/`,
and links the new layer files. Nothing is overwritten in place. Your stashed
edits stay recoverable with `git -C ~/dotfiles stash show -p`.

`dotfiles doctor` afterwards flags any legacy leftovers (old `stow/<pkg>`
directories still holding files) so you can review and remove them manually.

## What Gets Installed

Required core (`packages/global/apt.txt`): git, stow, tmux, fzf, ripgrep, jq,
bat, eza, fastfetch, btop, htop, ncdu, git-delta, direnv, tealdeer, vim-tiny,
zsh, curl, bash, wget, nano, bash-completion, tree, rsync, unzip, fd-find,
file.

External Debian package managed by `dotfiles update`: Yazi. Debian/Ubuntu stock
apt does not provide the required `yazi` package here, so the updater installs
or updates the latest stable official upstream GitHub `.deb` for supported
Debian architectures (`arm64`/`amd64`) and verifies the published SHA256 digest
before installing it with apt.

Server layer (`packages/os-debian/apt.txt`): ca-certificates,
unattended-upgrades.

Debian/Ubuntu naming quirks:

- `bat` installs the binary as `batcat`; `fd-find` installs `fdfind`.
- `tealdeer` provides the `tldr` command; Debian removed the old Haskell `tldr`
  package from current releases.
- `eza` and `fastfetch` need Debian 13+/Ubuntu 24.04+. When a declared package
  is unavailable, the batch apt install fails, `dotfiles update` retries per
  package, skips the unavailable ones with a warning, and everything else still
  installs. The shared aliases fall back to plain `ls` automatically.

Nothing that needs a third-party apt repo is declared by default (no
Tailscale, no Docker). Opt in per machine through the profile layer after
configuring the vendor repo:

```text
packages/profile-<hostname>-<os>/apt.txt   # e.g. packages/profile-domum-core-debian/apt.txt
```

## What Gets Stowed

On Debian/Ubuntu only `stow/global` and `stow/os-debian` apply. That means
shell, git, ssh, tmux, lightweight editor defaults, and the shared scripts. `stow/global` also
carries a few desktop-app config files (Ghostty, Alacritty, wallpaper
definitions); they are inert symlinks on a server because the apps are never
installed there. No Hyprland, Waybar, browser, theme, or login-manager
config exists outside the Omarchy/macOS layers.

## Zsh Preferred, Bash Fallback

- zsh is a bootstrap prerequisite, so it is always installed.
- Your login shell is not changed. `~/.bashrc` hands interactive bash sessions
  off to `zsh -l` when zsh exists, so the experience is zsh without touching
  `/etc/passwd`. To make it official (optional, never automated):

  ```bash
  chsh -s "$(command -v zsh)"
  ```

- If zsh is somehow unavailable, bash still sources the shared aliases,
  functions, and tmux layouts, plus safe history defaults (append mode,
  timestamps, dedupe, leading-space exclusion).
- If Powerlevel10k is missing, `.zshrc` falls back to the `robbyrussell`
  theme; if eza/fzf are missing, aliases degrade to `ls` equivalents. Nothing
  in the shell config hard-requires an optional tool.

## Fonts And The Local Terminal

Servers need no fonts — the prompt renders in whatever terminal you SSH from.
Powerlevel10k is configured in `nerdfont-v3` mode, so install a Nerd Font in
your local terminal (already true for Ghostty/Alacritty on managed machines):

- JetBrainsMono Nerd Font (repo default)
- MesloLGS, CaskaydiaCove, or Hack Nerd Fonts also work

If you must use a client without Nerd Fonts, run `p10k configure` on the
server once and pick the ASCII/unicode preset; it only writes `~/.p10k.zsh`
locally on that machine (overriding the stowed symlink is a stow conflict —
prefer `POWERLEVEL9K_MODE` override in `~/.config/shell/env.local`).

## History

- zsh: Oh My Zsh defaults — shared history across sessions, dedupe, and
  commands starting with a space are not saved.
- bash fallback: same properties via `HISTCONTROL=ignoreboth` + `histappend`.
- Atuin is **not** installed on servers by default (the config file is stowed
  but inert). Plain shell history is the default and the right answer for work
  servers.
- Personal servers may opt in manually when synced shell history is acceptable:

  ```bash
  sudo apt update
  sudo apt install atuin
  exec zsh
  atuin login -u <username>
  atuin sync
  ```

  If `atuin` is not in the server's stock apt repositories, leave it uninstalled
  unless you intentionally create a per-host package/profile exception. Full
  usage and recovery notes: [`atuin.md`](atuin.md).
- Never enable external history sync on work servers. To pause history in any
  shell, prefix the command with a space.

## Server Editors

Servers default to `vim.tiny` through `$EDITOR` and `$VISUAL`, not LazyVim. The
`v` helper opens `$VISUAL`, so `v file` remains muscle memory without depending
on Neovim plugins. `nano` remains installed for emergency edits.

If `nano` or `vim.tiny` renders wrong, debug terminal state before replacing the
editor. Most failures are missing terminfo, a stale enhanced-keyboard mode, or a
bad `$TERM`; see the Ghostty troubleshooting section below.

## Tmux And TDL Layouts

`~/.tmux.conf` and the `tdl`/`tdlm`/`tsl` layout functions work over plain
SSH — they need only tmux plus whichever agent/editor they launch. Missing
agents fail with a clear message and install nothing. See
[terminal-cheatsheet.md](terminal-cheatsheet.md) for the full command table.

## AI CLI Tools (Optional, Never Bootstrapped)

Nothing AI-related installs during bootstrap, and no API keys are ever
required or stored. On personal machines where you want them:

```bash
# Claude Code (needs Node 18+ or use the native installer)
npm install -g @anthropic-ai/claude-code
# opencode
curl -fsSL https://opencode.ai/install | bash
# Codex CLI
npm install -g @openai/codex
```

Authenticate interactively after install (`claude`, `opencode auth login`,
`codex login`). Check availability with `command -v claude opencode codex`.
`tdl c`, `tdl cx`, and `tsl N <agent>` pick them up automatically once
installed. On work servers, install only what your employer's policy allows,
and prefer per-project rather than global installs where practical.

## Security Updates (Installed By Default)

`unattended-upgrades` is declared in the server layer. Debian and Ubuntu ship
it enabled for the security pocket only, with auto-reboot off. Verify:

```bash
systemctl status unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades          # both values should be "1"
sudo unattended-upgrade --dry-run --debug | tail  # what would be applied
grep -h "Unattended-Upgrade" /var/log/unattended-upgrades/unattended-upgrades.log | tail
```

If `20auto-upgrades` is missing or zeroed:

```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

Leave `Unattended-Upgrade::Automatic-Reboot` at its default (`false`) unless
the machine is disposable and you understand the consequences. Optional
companion: `apt-listchanges` for changelog mail.

## Add A New Laptop SSH Key To A Server

Use this when a managed laptop knows a server alias, but the server does not
trust this laptop yet. Example symptom:

```text
ssh domum-core
jfranco@100.121.26.52: Permission denied (publickey,password).
```

Keys and `authorized_keys` are local machine state. Never commit them to this
repo. In this repo, only the SSH client config is tracked:

For disaster recovery, put private keys and server `authorized_keys` in the
encrypted recovery pack, not Git. See
[`recovery-pack.md`](recovery-pack.md).

```bash
git -C ~/dotfiles ls-files -- stow/global/ssh/.ssh
```

Expected tracked file:

```text
stow/global/ssh/.ssh/config
```

The real keys live outside Git in `~/.ssh/`:

```bash
ls -la ~/.ssh
```

Fix local SSH permissions before debugging anything else:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519 2>/dev/null || true
chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true
chmod 600 ~/.ssh/known_hosts 2>/dev/null || true
```

On the new laptop, create a key if it does not already exist:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "$(whoami)@$(hostname -s)"

# Copy the whole output line.
cat ~/.ssh/id_ed25519.pub
```

That command is intentionally quiet when the key already exists. If nothing
prints until `cat ~/.ssh/id_ed25519.pub`, it reused the existing key.

The key filename is not what grants access. The server checks whether the
public key line appears in `~/.ssh/authorized_keys` on the server. A key named
`id_ed25519`, `id_ed25519-fornax`, or anything else works if SSH is configured
to offer it and the server trusts the matching public key.

If the server still allows password login, this is the easiest path:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub domum-core
ssh domum-core
```

`ssh-copy-id` is only a helper. It must log in first, either with a password or
with another key that already works. If it fails like this, the server did not
accept any current login method from this laptop:

```text
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
jfranco@100.121.26.52: Permission denied (publickey,password).
```

If password login is disabled, use another machine that already has access:

```bash
ssh domum-core
```

Then, on the server, paste the new laptop public key into this command. Replace
the example key with the full line from `cat ~/.ssh/id_ed25519.pub`:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

printf '%s\n' 'ssh-ed25519 PASTE_THE_NEW_LAPTOP_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys

chmod 600 ~/.ssh/authorized_keys
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
```

Test from the new laptop:

```bash
ssh domum-core
```

If that still fails, debug with verbose SSH from the new laptop:

```bash
ssh -v domum-core
```

Optional named per-machine key, useful when you want the laptop name in the key
filename:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519-fornax -C "$(whoami)@fornax"
cat ~/.ssh/id_ed25519-fornax.pub
```

Because the stowed SSH config uses `IdentitiesOnly yes` for personal servers,
tell SSH about any non-default key in the untracked local include file:

```bash
cat >> ~/.ssh/config.local <<'EOF'
Host domum-core domum-core-tail domum-core-lan
  IdentityFile ~/.ssh/id_ed25519-fornax
EOF

chmod 600 ~/.ssh/config.local
```

Then add `~/.ssh/id_ed25519-fornax.pub` to `~/.ssh/authorized_keys` on the
server using the same existing-access path above.

Quick troubleshooting:

| Symptom | Meaning | Fix |
|---|---|---|
| `test -f ... || ssh-keygen ...` prints nothing | the key already exists | run `cat ~/.ssh/id_ed25519.pub` |
| `ssh-copy-id` says permission denied | the server does not yet trust this laptop and password login did not work | add the public key from another trusted machine/session |
| Tailscale says policy does not permit your local macOS/Linux username | the host alias has no remote `User`, so SSH reused the client's username | add the server alias and its Linux account to the stowed SSH config; personal servers use `jfranco` |
| Tailscale prints an authentication URL | the SSH policy requires a periodic identity check | open the URL, authenticate, then reconnect |
| key has the same filename as another laptop | not a problem by itself | access depends on public key contents, not filename |
| using `id_ed25519-fornax` | SSH may not offer it automatically because `IdentitiesOnly yes` is set | add `IdentityFile` in `~/.ssh/config.local` |
| worried keys were committed | keys should be local under `~/.ssh` | check `git -C ~/dotfiles status --short` and `git -C ~/dotfiles ls-files -- stow/global/ssh/.ssh` |

## SSH And Login Hardening (Documented, Never Automated)

This repo never edits `sshd_config` or firewall rules on servers. Recommended
manual checklist, in order of safety:

1. Use SSH keys; confirm key login works **before** any restriction.
2. Check who is knocking: `sudo lastb | head`, `journalctl -u ssh -n 50`.
3. fail2ban (optional):

   ```bash
   sudo apt install fail2ban
   # Debian 12+ has no auth.log by default; use the systemd backend:
   printf '[sshd]\nenabled = true\nbackend = systemd\n' | sudo tee /etc/fail2ban/jail.d/sshd.local
   sudo systemctl enable --now fail2ban && sudo fail2ban-client status sshd
   ```

4. Only after key login is verified from a second session, edit
   `/etc/ssh/sshd_config.d/hardening.conf`:

   ```text
   PermitRootLogin no
   PasswordAuthentication no
   ```

   Validate with `sudo sshd -t`, reload with `sudo systemctl reload ssh`, and
   keep the current session open until a fresh login succeeds.
5. ufw is available but **not** enabled by this repo on servers. If you enable
   it, allow SSH first: `sudo ufw allow OpenSSH && sudo ufw enable`.
6. Day-to-day: log in as a sudo user, not root.

## Troubleshooting: Ghostty SSH, nano Ctrl-X, terminfo, zsh

Symptoms over SSH from Ghostty (while Alacritty/Terminal.app look fine):
garbled or repeated-looking input while typing, prompt redraw glitches, nano
not exiting on Ctrl-X. Cause, almost always: the server has no terminfo entry
for `xterm-ghostty`, so zle and ncurses apps drive the terminal blind.

Diagnose on the server, in order:

```bash
echo "$TERM $COLORTERM"
infocmp "$TERM" >/dev/null && echo "terminfo ok" || echo "terminfo missing"
od -An -tx1      # press Ctrl-X, Enter, then Ctrl-D; healthy output is: 18 0a
ssh -t <host> 'zsh -f'          # plugin-free zsh; if this is clean, suspect plugins
TERM=xterm-256color ssh <host>  # fallback TERM; if this is clean, it's terminfo
```

Fixes, most permanent first:

1. **Client side (preferred):** Ghostty >= 1.2 with
   `shell-integration-features = ...,ssh-env,ssh-terminfo` (already in the
   stowed Ghostty config). `ssh-terminfo` installs `xterm-ghostty` on the
   remote host via `infocmp | tic` on first connect and caches it; if the
   install fails, `ssh-env` falls back to `TERM=xterm-256color`. Manage the
   cache with `ghostty +ssh-cache`. Any machine that does not want this can
   opt out in its profile override
   (`~/.config/ghostty/profile-overrides`, profile stow layer):
   `shell-integration-features = no-ssh-terminfo,no-ssh-env`.
2. **One-time manual install, run from your local machine:**

   ```bash
   infocmp -x xterm-ghostty | ssh <host> -- tic -x -
   ```

3. **Server-side fallback (already stowed):** `.zshrc`/`.bashrc` check
   `infocmp "$TERM"` at startup and export `TERM=xterm-256color` when the
   entry is missing, so full-screen apps keep working even with none of the
   above. Covers SSH, Tailscale SSH, and any remote session. Local desktop
   shells are inert because their terminfo is installed locally.
4. **This session only:** `export TERM=xterm-256color`.

If keys still arrive mangled after terminfo is fixed, a program probably left
an enhanced keyboard protocol (Kitty CSI-u / modifyOtherKeys) enabled — the
stowed zsh setup (Oh My Zsh + autosuggestions + syntax-highlighting + p10k)
never enables these, but a crashed nvim or a foreign rc can. Reset it, then
retest nano:

```bash
printf '\e[<u\e[>4;0m'   # pop Kitty keyboard flags, reset modifyOtherKeys
reset                     # full terminal reset if that was not enough
```

Stale completion cache (errors like `_arguments:comparguments:327` or
completions from another zsh version):

```bash
rm -f ~/.zcompdump*; exec zsh
```

`dotfiles doctor` runs the terminfo check automatically and prints the exact
remediation commands.

## Work vs Personal Servers

| Concern | Work server | Personal server |
|---|---|---|
| Git identity | create `~/.gitconfig.local` with work name/email (loaded last, wins) | stowed default is fine |
| SSH hosts | put employer hosts in `~/.ssh/config.local` (already included, untracked) | stowed config + `config.local` |
| History sync | plain history only | Atuin sync optional |
| AI CLIs | per policy only | install freely |
| Tailscale/Syncthing | no | opt-in via profile apt list |
| Security updates | unattended-upgrades (default) | same |

For always-on personal servers such as `domum-core`, disable Tailscale key expiry
in the Tailscale admin console. Otherwise SSH/tmux access can stop on the expiry
date even though the machine is healthy.

The stowed `~/.ssh/config` contains personal host aliases; on a work machine
where that is inappropriate, skip stow for that package by removing the
symlink and keeping a local file (stow backs up, never overwrites).

## Rollback / Removal

On hosts migrated from the old flat layout, confirm `~/.ssh` is a real
directory first (`ls -la ~/.ssh`) — if it is still a symlink into the repo,
removing `~/dotfiles` deletes your keys and `authorized_keys`.

```bash
cd ~/dotfiles
stow -d stow -t "$HOME" -D global os-debian   # remove symlinks
rm -f ~/.local/bin/dotfiles
rm -rf ~/dotfiles ~/.oh-my-zsh                # optional, full removal
```

Backups made during bootstrap remain in `~/.dotfiles-backup/`.
