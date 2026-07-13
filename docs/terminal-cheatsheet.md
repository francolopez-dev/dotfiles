# Terminal Cheatsheet

One reference for the managed terminal experience on macOS, Omarchy, and
minimal Debian/Ubuntu servers. Commands are ordered by how often they are used.

## Daily Commands

| Command | Use it for | Notes |
|---|---|---|
| `dotfiles status` | Check machine, layers, packages, stow state | First command when something feels off |
| `dotfiles update` | Pull repo, install packages, re-stow | Daily maintenance |
| `dotfiles update --dry-run` | Preview update | No changes |
| `dotfiles apply` | Re-stow after editing config | Does not install packages |
| `dotfiles commands search <q>` | Find aliases, layouts, keybinds | Example: `dotfiles commands search fzf` |
| `v` | Open Neovim | Alias for `nvim` |
| `y` | Open Yazi | Terminal file manager |
| `l` | Pretty compact file listing | eza-backed, falls back to `ls` |
| `ll` | Full file listing | Adds git/user/permission columns |
| `lt` | Small tree view | Two levels when eza exists |
| `cat <file>` | Pretty file view | Uses `bat`; Debian/Ubuntu fallback is `batcat` |
| `cd <dir>` | Smart directory jump | zoxide on macOS/Omarchy; normal `cd` fallback |
| `tldr <cmd>` | Quick examples | Faster than reading a full man page |
| `man <cmd>` | Manual pages | Colorized through bat/batcat when available |

## Smart Replacements

| Old habit | Managed habit | What changes |
|---|---|---|
| `cat file` | `cat file` | Same command, prettier output through bat |
| `cd long/path` | `cd partial-name` | zoxide jumps to frequent directories after learning them |
| `ls` | `l` / `ll` | Icons, git status, compact table |
| `find . -name foo` | `fd foo` | Faster, simpler search. Debian binary is `fdfind` |
| `grep -R text` | `rg text` | Fast recursive text search |
| `du -sh *` | `ncdu` | Interactive disk usage browser |
| `git diff` | `git diff` | Same command, delta pager when installed |
| `command --help` | `tldr command` | Practical examples first |

## Files And Search

| Command | Does |
|---|---|
| `l` | Compact listing with hidden files, colors, icons, git, relative time |
| `ll` | Full listing with git, user, and permissions |
| `l --raw` / `ll --raw` | Original eza/ls output without boxed table |
| `lt` | Directory tree |
| `fd ssh` | Find paths matching `ssh` |
| `fd -e md terminal` | Find markdown files matching `terminal` |
| `rg TODO` | Search file contents for `TODO` |
| `rg -n "foo.*bar"` | Regex search with line numbers |
| `ncdu` | Inspect disk usage from current directory |
| `sudo ncdu /var` | Inspect a system directory |

Debian/Ubuntu package names differ: use `fdfind` if you call fd directly and
`batcat` if you bypass the `cat` alias.

## Fzf

Fzf is the fuzzy picker. Type a few letters, use arrow keys or `Ctrl+J/K`, then
press Enter.

| Shortcut | Does |
|---|---|
| `Ctrl+R` | Fuzzy search shell history |
| `Ctrl+T` | Insert selected file(s) into the current command |
| `Alt+C` | Jump to a selected directory |
| `**<Tab>` | Fuzzy complete paths in many shell commands |

Examples:

```bash
nvim **<Tab>      # fuzzy-pick a file to edit
git add **<Tab>   # fuzzy-pick files to stage
# Press Alt+C at an empty prompt to fuzzy-pick a directory.
```

Fzf uses `fd`/`fdfind` as its file source when available, including hidden files
but excluding `.git`.

## Navigation

| Command | Does |
|---|---|
| `cd ~/projects/foo` | Normal cd still works |
| `cd foo` | Jump to a frequent matching directory with zoxide |
| `z foo` | Alias to smart `cd`, kept for muscle memory |
| `cd -` | Previous directory |
| `..` | Parent directory |

Zoxide learns only after you visit directories. If a jump goes somewhere
unexpected, use the full path once and it will learn the better match.

## Git

| Command | Does |
|---|---|
| `gs` | `git status` |
| `gp` | `git pull` |
| `gl` | `git log --oneline --decorate --graph --all -10` |
| `git diff` | Delta-powered diff when `delta` is installed |
| `git show` | Delta-powered commit view |
| `git log -p` | Commit log with patches through delta |
| `git add -p` | Interactive staging |
| `git -C ~/dotfiles status --short --branch` | Check dotfiles repo quickly |
| `dotfiles git setup-ssh` | Guided GitHub SSH setup |

Delta config is intentionally simple: line numbers on, side-by-side off, moved
lines highlighted, and conflict style set to `zdiff3` for clearer merge files.

## Project Environments With Direnv

Direnv loads environment variables when you enter a trusted project directory.

| Command | Does |
|---|---|
| `direnv allow` | Trust this directory's `.envrc` |
| `direnv deny` | Stop trusting it |
| `direnv status` | Show current direnv state |
| `direnv reload` | Reload after editing `.envrc` |

Typical `.envrc`:

```bash
export PROJECT_ENV=dev
PATH_add bin
```

Never commit secrets in `.envrc`. Put secret values in untracked local files or
Vaultwarden-owned workflows.

## Tmux

Prefix is `Ctrl+B`.

| Keys | Does |
|---|---|
| `Ctrl+B \|` | Split left/right |
| `Ctrl+B -` | Split top/bottom |
| `Ctrl+B h/j/k/l` | Move between panes |
| `Ctrl+B n` / `p` | Next / previous window |
| `Ctrl+B w` | Choose window |
| `Ctrl+B d` | Detach session |
| `Ctrl+B r` | Reload tmux config |
| `tmux attach` | Reattach after disconnect |

Mouse support is on for pane selection, resizing, and scrollback.

## TDL Agent Layouts

These create tmux layouts for coding sessions. Missing agents fail with a clear
message and install nothing.

| Command | Layout |
|---|---|
| `tdl c` | editor + opencode + shell |
| `tdl cx` | editor + claude + shell |
| `tdl c cx` | editor + opencode + claude + shell |
| `tdlm c` | one tmux window per immediate subdirectory |
| `tsl 4 c` | four tiled opencode panes |
| `ic` / `icx` / `icl` | aliases for `tdl c` / `tdl c cx` / `tdl cx` |

Agent names: `c`/`oc` = `opencode`, `cx` = `claude`, `codex` = `codex`.

## Dotfiles Helpers

| Command | Does |
|---|---|
| `repo status` | Branch, clean/sync state, open tasks |
| `repo todo` | Open `.repo/TODO.md` |
| `repo todo add <task>` | Append a repo task |
| `repo notes` | Open `.repo/NOTES.md` |
| `repo decisions` | Open `.repo/DECISIONS.md` |
| `repo omarchy-todo` | Open shared Omarchy todo file |

## History

| Tool | Where | Notes |
|---|---|---|
| zsh history | all machines | Shared, deduped, leading-space commands skipped |
| bash fallback | minimal/fallback shells | Append mode, timestamps, `ignoreboth` |
| `Ctrl+R` | fzf history search | Best daily history picker |
| Atuin | macOS/Omarchy | Run `atuin login && atuin sync` to sync |
| Servers | Debian/Ubuntu | Plain history by default; Atuin is opt-in only |

## Server Diagnostics

| Command | Use it for |
|---|---|
| `systemctl status <svc>` | Service state |
| `journalctl -u <svc> -n 50` | Recent service logs |
| `ss -tulpn` | Listening ports |
| `df -h` | Mounted disk usage |
| `ncdu /path` | Interactive disk usage |
| `ip a` | Network addresses |
| `sudo lastb | head` | Failed logins |
| `free -h` | Memory |
| `btop` | Interactive CPU/memory/process view |

Hardening and Ghostty SSH troubleshooting live in
[`server-minimal.md`](server-minimal.md).

## Config Locations

| Thing | File |
|---|---|
| Shared aliases/functions | `stow/global/shell/.config/shell/aliases.sh` |
| Shared env, fzf defaults, pager defaults | `stow/global/shell/.config/shell/env.sh` |
| Zsh startup, fzf hooks, zoxide, direnv | `stow/global/zsh/.zshrc` |
| Bash fallback startup | `stow/global/bash/.bashrc` |
| Tmux | `stow/global/tmux/.tmux.conf` |
| Git/delta | `stow/global/git/.gitconfig` |
| Ghostty | `stow/global/ghostty/.config/ghostty/config` |
| Discovery registry | `stow/global/discovery/.config/dotfiles/commands.tsv` |

## Troubleshooting

| Problem | Try |
|---|---|
| Shell command not found after update | `exec zsh` or open a new terminal |
| `cd foo` jumps wrong | `cd /full/correct/path` once so zoxide relearns |
| fzf shortcuts do nothing | Confirm shell integration files exist: `command -v fzf` then `exec zsh` |
| `git diff` complains about delta | Confirm `command -v delta`; unset with `unset GIT_PAGER` for this shell |
| Man pages look plain | Confirm `command -v bat batcat` |
| zsh completion errors | `rm -f ~/.zcompdump*; exec zsh` |
| Stow conflict | `dotfiles apply --dry-run`, then choose backup in the conflict wizard |

## Package Names

| Tool | macOS/Homebrew | Omarchy/Arch | Debian/Ubuntu |
|---|---|---|---|
| bat | `bat` | `bat` | package `bat`, binary `batcat` |
| fd | `fd` | `fd` | package `fd-find`, binary `fdfind` |
| delta | `git-delta` | `git-delta` | `git-delta` where available |
| fzf | `fzf` | `fzf` | `fzf` |
| zoxide | `zoxide` | `zoxide` | not global by default |
| direnv | `direnv` | `direnv` | `direnv` |
