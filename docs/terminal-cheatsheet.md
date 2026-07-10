# Terminal Cheatsheet

Everything below is collected from real files in this repo — aliases from
`stow/global/shell/.config/shell/aliases.sh`, layouts from
`stow/global/shell/.config/shell/tmux-layouts.sh`, keys from
`stow/global/tmux/.tmux.conf`, and the discovery registry
(`stow/global/discovery/.config/dotfiles/commands.tsv`, searchable with
`dotfiles commands search <query>`). Works on Omarchy, macOS, and minimal
Debian/Ubuntu servers unless marked otherwise.

## Dotfiles CLI

| Command | Does |
|---|---|
| `dotfiles status` | Machine, layers, package drift, sync tools, recovery pack |
| `dotfiles update` | Pull, install missing packages, re-stow layers |
| `dotfiles update --dry-run` | Show what update would do |
| `dotfiles apply` | Re-stow layers after editing configs |
| `dotfiles doctor` | Bootstrap/desktop health checks |
| `dotfiles commands list` / `search <q>` | Browse/search this registry |
| `dotfiles git setup-ssh` | Guided GitHub SSH setup |
| `dotfiles autostart status` | Audit login/startup items |
| `dotfiles wallpaper rotate` | Omarchy only |

## Shell Aliases And Functions

Sourced by both zsh and bash from the shared `aliases.sh`.

| Alias | Expands to | Notes |
|---|---|---|
| `..` | `cd ..` | |
| `gs` | `git status` | |
| `gp` | `git pull` | |
| `dps` | `docker ps` | needs docker |
| `dcu` / `dcd` | `docker compose up -d` / `down` | needs docker |
| `ff` | `fastfetch` | silent if not installed |
| `v` | `nvim` | |
| `y` | `yazi` | Omarchy/macOS; not installed on servers |
| `l` | styled compact listing | eza-backed, falls back to `ls -lh` |
| `ll` | styled full listing (+git, owner, perms) | falls back to `ls -lha` |
| `la` | same as `l` | |
| `lt` | two-level tree | falls back to `ls -lah` |
| `l --raw` / `ll --raw` | raw eza/ls output, no box table | |
| `cls` | clear screen + scrollback | |
| `z <dir>` | zoxide jump | zsh only, needs zoxide (Omarchy/macOS) |
| `work` / `rest` | pomodoro timers | needs `timer`, otherwise prints a notice |

Oh My Zsh plugins loaded in `.zshrc`: `git` (adds `gst`, `gco`, `glog`, ...),
`docker-compose`, `python`, `nmap`, plus autosuggestions and syntax
highlighting installed by bootstrap.

## Git Shortcuts

| Command | Does |
|---|---|
| `gs` / `gp` | status / pull (shared aliases) |
| OMZ `git` plugin | `gst`, `ga`, `gc`, `gco`, `gd`, `glog`, ... (zsh only) |
| `dotfiles git setup-ssh` | guided GitHub SSH key setup |
| `~/.gitconfig.local` | untracked per-machine identity override (work servers) |

More detail: [git-github-cheatsheet.md](git-github-cheatsheet.md).

## Tmux (prefix is Ctrl+B)

| Keys | Does |
|---|---|
| `Ctrl+B \|` / `Ctrl+B -` | split left/right / top/bottom |
| `Ctrl+B h/j/k/l` | move between panes (vim-style) |
| `Ctrl+B n` / `p` / `w` | next / previous / choose window |
| `Ctrl+B d` | detach (session keeps running) |
| `Ctrl+B r` | reload `~/.tmux.conf` |
| mouse | on (click panes, scroll, resize) |
| `tmux attach` | reattach after SSH reconnect |

## TDL / Agent Sessions

Layout functions work anywhere tmux + the requested command exist; missing
agents fail with a clear error and install nothing.

| Command | Layout |
|---|---|
| `tdl c` | editor + opencode + shell (one session per directory) |
| `tdl cx` | editor + claude + shell |
| `tdl c cx` | editor + opencode + claude + shell |
| `tdlm c` | one tmux window per immediate subdirectory |
| `tsl 4 c` | four tiled agent panes (2–8 allowed) |
| `ic` / `icx` / `icl` | aliases for `tdl c` / `tdl c cx` / `tdl cx` |

Agent name mapping: `c`/`oc` → `opencode`, `cx` → `claude`, `codex` → `codex`.
Rerunning `tdl` in the same directory reattaches to the existing session.

## AI CLI Tools

Not installed on servers by default; see
[server-minimal.md](server-minimal.md#ai-cli-tools-optional-never-bootstrapped)
for install/auth. Check availability: `command -v claude opencode codex`.

## Editing

| Command | Does |
|---|---|
| `v` / `nvim` | Neovim (LazyVim config, stowed everywhere) |
| `nano` | installed everywhere as the fallback editor |
| `$EDITOR` | defaults to `nvim` via `env.sh` |

## History

| Where | Behaviour |
|---|---|
| zsh (all machines) | OMZ defaults: shared, deduped; leading space is not saved |
| bash fallback (servers without zsh) | append mode, timestamps, `ignoreboth` |
| Atuin (Omarchy/macOS) | `Ctrl+R` search; `atuin login && atuin sync` to sync |
| Servers | plain history by default; Atuin is opt-in, never on work servers |

## Repo Helper (`repo`, stowed everywhere)

| Command | Does |
|---|---|
| `repo status` | branch, clean/sync state, open tasks |
| `repo todo` / `repo todo add <task>` | open/append `.repo/TODO.md` |
| `repo notes` / `repo decisions` | open `.repo/NOTES.md` / `DECISIONS.md` |
| `repo omarchy-todo [add <task>]` | shared todo at `~/Documents/Notes/todo.txt` |

## Server Diagnostics (standard tools, no aliases)

Installed by the minimal server package set: `htop`, `btop`, `tree`, `rsync`,
`jq`, `ripgrep` (`rg`), `fd-find` (`fdfind`), `bat` (`batcat`), `fzf`.
Standard commands worth remembering: `journalctl -u <svc> -n 50`,
`systemctl status <svc>`, `ss -tulpn`, `df -h`, `du -sh *`, `ip a`,
`sudo lastb | head` (failed logins). Hardening commands live in
[server-minimal.md](server-minimal.md).

## Omarchy-Only (not on servers)

Desktop keybindings (`Super+C/V/A`, `Ctrl+1..9`, quake terminal `` Ctrl+` ``,
notes/todo drawers, screenshots) and `dotfiles wallpaper` — full list via
`dotfiles commands list` or `Super+K`. See [terminal-ux.md](terminal-ux.md).

## Recommended Additions (do not exist yet)

Nothing here is implemented; add to `aliases.sh` + the discovery registry if
adopted: a `gd`/`gl` git-diff/log alias pair for bash sessions, and a `sysinfo`
wrapper for the diagnostics block above.
