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
| `t` | Open or return to tmux for this directory | Best default for project work |
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
| `Ctrl+R` | Atuin history search when installed; fzf history fallback otherwise |
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

Use tmux for terminal tabs, panes, and long-running work. Start simple: one
Ghostty window, one tmux session per project, tmux windows as tabs, panes only
when you actually need a split.

Mental model:

| Thing | Think of it as | Example |
|---|---|---|
| Ghostty window | The physical terminal app window | One tiled AeroSpace window |
| tmux session | A saved terminal workspace | `dotfiles`, `work`, `server` |
| tmux window | A tab inside that workspace | editor, shell, logs |
| tmux pane | A split inside one tab | editor next to server logs |
| detach | Hide tmux but keep it running | Leave work and come back later |

### First Week Workflow

This is the workflow to use until tmux feels normal:

```bash
cd ~/dotfiles
t
```

Inside tmux, learn only these first:

| Keys | Does |
|---|---|
| `Ctrl+B c` | New tmux window, like a terminal tab |
| `Ctrl+B n` | Next tmux window |
| `Ctrl+B p` | Previous tmux window |
| `Ctrl+B ,` | Rename current tmux window |
| `Ctrl+B w` | Pick from all tmux windows |
| `Ctrl+B d` | Detach and leave everything running |

Use `Ctrl+B d` instead of closing Ghostty. Later, run `t` from the same project
directory to return to that session.

### Beginner Commands

| Command | Does |
|---|---|
| `t` | Open or return to tmux for the current directory |
| `t work` | Open or return to a named session called `work` |
| `tl` | List running tmux sessions |
| `ta work` | Attach/switch to named session `work` |
| `tk work` | Kill named session `work` |

If `tl` shows many sessions, do not panic. A session is just a saved workspace.
Attach with `ta <name>` if you still need it, or kill it with `tk <name>` if you
are done.

### What To Do When It Feels Messy

| Situation | Do this |
|---|---|
| Too many tmux windows | Press `Ctrl+B w`, choose the one you want |
| Window names are confusing | Press `Ctrl+B ,` and rename the current window |
| You are done for now | Press `Ctrl+B d`, do not close every pane |
| You opened tmux twice | Use `tl`, then `ta <name>` to pick the right session |
| You are done forever | Use `tk <name>` from a normal shell |
| A pane is taking the whole screen | Press `Ctrl+B z` to unzoom it |

### Panes, Only After Windows Make Sense

Prefix is `Ctrl+B`. Press and release `Ctrl+B`, then press the next key.

| Keys | Does |
|---|---|
| `Ctrl+B \|` | Split left/right |
| `Ctrl+B -` | Split top/bottom |
| `Ctrl+B h/j/k/l` | Move between panes |
| `Ctrl+B z` | Zoom/unzoom current pane |
| `Ctrl+B x` | Kill current pane |

Mouse support is on for pane selection, resizing, and scrollback.

### Later Reference

Start and reattach:

| Command | Does |
|---|---|
| `tmux new -s work` | Start a named session |
| `tmux attach` | Attach to the most recent session |
| `tmux attach -t work` | Attach to a named session |
| `tmux ls` | List sessions |
| `tmux kill-session -t work` | Kill one session |
| `tmux rename-session -t old new` | Rename a session |
| `tmux switch -t work` | Switch sessions from inside tmux |

Window keys:

| Keys | Does |
|---|---|
| `Ctrl+B c` | New window |
| `Ctrl+B n` / `p` | Next / previous window |
| `Ctrl+B 0-9` | Jump to window number |
| `Ctrl+B w` | Choose window |
| `Ctrl+B ,` | Rename current window |
| `Ctrl+B d` | Detach session |
| `Ctrl+B r` | Reload tmux config |

Pane and window layout:

| Keys | Does |
|---|---|
| `Ctrl+B Space` | Cycle pane layouts |
| `Ctrl+B {` / `}` | Move pane left / right in the layout |
| `Ctrl+B !` | Break pane out into its own window |
| `Ctrl+B :join-pane -t :1` | Move current pane into window 1 |
| `Ctrl+B :swap-window -s 2 -t 1` | Swap window 2 with window 1 |

Scrollback and copy mode:

| Keys | Does |
|---|---|
| `Ctrl+B [` | Enter copy/scrollback mode |
| `q` | Exit copy mode |
| `Space` | Start selection in copy mode |
| `Enter` | Copy selection in copy mode |
| `Ctrl+B ]` | Paste tmux buffer |
| `Ctrl+B =` | Choose a paste buffer |

In Ghostty on macOS, use tmux windows instead of Ghostty tabs when running under
AeroSpace. This avoids native tab/window-manager edge cases while keeping
terminal tabs.

Recommended project pattern:

```bash
t
# Create tmux windows with Ctrl+B c, rename with Ctrl+B ,.
# Detach with Ctrl+B d; later cd back to the project and run: t
```

If a terminal closes, the tmux session keeps running unless the machine rebooted
or the session was killed. Reattach before starting duplicate long-running jobs.

## Omarchy Window Manager

Shared Omarchy desktop keybindings live in
[`omarchy-keybindings.md`](omarchy-keybindings.md).

| Keys | Does |
|---|---|
| `Ctrl+H/J/K/L` | Focus tiled windows left/down/up/right |
| `Ctrl+equal` / `Ctrl+plus` | Horizontal resize with Hyprland `resizeactive 100 0` |
| `Ctrl+minus` | Horizontal resize with Hyprland `resizeactive -100 0` |

Known tradeoff: these are Hyprland global bindings, so they can intercept app
shortcuts such as browser zoom and terminal/editor control keys.

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
| `Ctrl+R` | macOS/Omarchy | Atuin owns history search when installed |
| Atuin | macOS/Omarchy | Run `atuin login -u <username> && atuin sync`; guide: [`atuin.md`](atuin.md) |
| Servers | Debian/Ubuntu | Plain history by default; personal-server Atuin is manual opt-in only |

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
| Atuin shortcuts do nothing | Confirm `command -v atuin`, then `exec zsh`; full guide: [`atuin.md`](atuin.md) |
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
