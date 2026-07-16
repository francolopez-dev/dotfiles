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

## Neovim

This repo uses LazyVim from `stow/global/neovim/.config/nvim/`. Keep the core
Vim habits intact: `y` yanks/copies, `p` pastes, `c` changes text, and `Ctrl+C`
is not a generic copy shortcut.

Daily editing:

| Keys | Does |
|---|---|
| `v` | Start character selection |
| `V` | Start line selection |
| `y` | Yank/copy the selected text |
| `yy` | Yank/copy the current line |
| `p` / `P` | Paste after / before the cursor |
| `d` | Delete selection or motion |
| `c` | Change selection or motion, then enter insert mode |
| `u` | Undo |
| `Ctrl+R` | Redo |
| `Esc` | Leave insert/visual mode, clear search highlight in LazyVim |

Movement and search:

| Keys | Does |
|---|---|
| `h/j/k/l` | Move left/down/up/right |
| `w` / `b` | Next / previous word |
| `0` / `$` | Start / end of line |
| `gg` / `G` | Top / bottom of file |
| `/text` | Search forward |
| `n` / `N` | Next / previous search match |
| `s` | LazyVim Flash jump |

Files, buffers, and windows:

| Keys | Does |
|---|---|
| `<leader><space>` | Find files from the project root |
| `<leader>/` | Grep/search project text |
| `<leader>,` | Pick an open buffer |
| `Shift+H` / `Shift+L` | Previous / next buffer |
| `<leader>e` | Open the file explorer |
| `<leader>-` | Split window below |
| `<leader>\|` | Split window right |
| `Ctrl+H/J/K/L` | Move between Neovim windows |
| `<leader>wd` | Delete the current Neovim window |

Save, quit, and help discovery:

| Keys | Does |
|---|---|
| `Ctrl+S` | Save file in LazyVim |
| `:w` | Save file |
| `:q` | Quit current window |
| `:wq` | Save and quit |
| `:qa` | Quit all |
| `<leader>?` | Show buffer keymaps |
| `<leader>sk` | Search all keymaps |
| `<leader>p` | Open Yanky yank history |

Clipboard note: LazyVim's Yanky extra is enabled in this repo. Normal `y`, `p`,
and `P` are the primary Neovim copy/paste workflow; use Ghostty-native
selection only when you intentionally want terminal text outside Neovim's buffer
model.

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

Inside tmux, learn only these first. `Ctrl+Space` is the preferred prefix;
`Ctrl+B` remains enabled as the tmux default and fallback.

| Keys | Does |
|---|---|
| `Ctrl+Space c` | New tmux window, like a terminal tab |
| `Ctrl+Space n` | Next tmux window |
| `Ctrl+Space p` | Previous tmux window |
| `Ctrl+Space Tab` | Last tmux window, like quick back-and-forth |
| `Ctrl+Space ,` | Rename current tmux window |
| `Ctrl+Space w` | Pick from all tmux windows |
| `Ctrl+Space d` | Detach and leave everything running |

Use `Ctrl+Space d` instead of closing Ghostty. Later, run `t` from the same
project directory to return to that session. If `Ctrl+Space` is intercepted by
an input method or app on a machine, use `Ctrl+B` with the same second key.

New windows ask for a name. Use short role names such as `editor`, `server`,
`logs`, `git`, or `scratch`; tmux will keep the name stable instead of changing
it to whatever subprocess is currently active.

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
| Too many tmux windows | Press `Ctrl+Space w`, choose the one you want |
| Window names are confusing | Press `Ctrl+Space ,` and rename the current window |
| You want to remove a whole tab/window | Press `Ctrl+Space X` and confirm |
| You want to remove only one split/pane | Press `Ctrl+Space x` and confirm |
| You are done for now | Press `Ctrl+Space d`, do not close every pane |
| You opened tmux twice | Use `tl`, then `ta <name>` to pick the right session |
| You are done forever | Use `tk <name>` from a normal shell |
| A pane is taking the whole screen | Press `Ctrl+Space z` to unzoom it |

If you are not sure whether something is a session, window, or pane, press
`Ctrl+Space w`. tmux opens a tree with previews. Use arrows to move, `Enter` to
switch, `x` to kill the selected item, and `q` to leave without changing
anything.

The tmux status bar stays at the bottom and uses the same dark/green/purple/yellow
palette as Ghostty, Waybar, and SketchyBar. The left status block changes color
by mode:

| Status | Meaning |
|---|---|
| `READY` | Normal tmux state |
| `PREFIX` | You pressed `Ctrl+Space` or `Ctrl+B`; tmux is waiting for the next key |
| `COPY` | The active pane is in copy/scrollback mode |
| `ZOOM` | The active pane is temporarily fullscreened with `Ctrl+Space z` |

### Panes, Only After Windows Make Sense

Preferred prefix is `Ctrl+Space`. Press and release `Ctrl+Space`, then press the
next key. `Ctrl+B` still works everywhere as a compatibility fallback.

| Keys | Does |
|---|---|
| `Ctrl+Space \|` | Split left/right |
| `Ctrl+Space -` | Split top/bottom |
| `Ctrl+Space h/j/k/l` | Move between panes |
| `Ctrl+Space H/J/K/L` | Resize panes left/down/up/right; keep tapping `H/J/K/L` to repeat |
| `Ctrl+Space z` | Zoom/unzoom current pane |
| `Ctrl+Space x` | Kill current pane |

Mouse support is on for pane selection, resizing, and scrollback.

### Ghostty And Tmux Clipboard Workflow

This repo does not remap Ghostty, Hyprland, AeroSpace, or OS-level copy/paste
shortcuts for tmux. tmux gets its own small workflow instead.

Mental model:

| Layer | Owns | Use it when |
|---|---|---|
| Ghostty / OS clipboard | Native terminal selection and Cmd/Super/Ctrl+Shift copy-paste | You selected text with Ghostty, usually by holding `Shift` while dragging inside tmux |
| tmux buffer and copy mode | Pane-aware scrollback, pane-aware mouse selection, tmux paste buffer | You want text from one tmux pane or its history |
| Shell, Neovim, or TUI app | Process input and app shortcuts | You are interacting with a running program; plain `Ctrl+C` remains interrupt |

Shortcut reference:

| Task | macOS | Omarchy/Arch | Notes |
|---|---|---|---|
| Preferred tmux prefix | `Ctrl+Space` | `Ctrl+Space` | `Ctrl+B` still works as fallback |
| Enter pane copy mode | `Ctrl+Space Space` | `Ctrl+Space Space` | Pane-specific scrollback |
| Start selection in copy mode | `v` | `v` | Vim/Neovim-style selection |
| Select current line in copy mode | `V` | `V` | Useful for command output lines |
| Copy tmux selection | `c` or `y` | `c` or `y` | Saves to tmux buffer and OS clipboard through OSC 52 |
| Paste tmux buffer | `Ctrl+Space v` | `Ctrl+Space v` | Existing `Ctrl+Space ]` also works |
| Native Ghostty selection | `Shift+drag`, then `Cmd+C` | `Shift+drag`, then existing terminal copy shortcut | Bypasses tmux; not pane-history aware |
| Interrupt a process | `Ctrl+C` | `Ctrl+C` | Not remapped to copy |

Which copy method should you use?

| Situation | Use |
|---|---|
| Visible text in one tmux pane | Mouse drag in tmux, or `Ctrl+Space Space`, select, `c`/`y` |
| Pane scrollback/history | `Ctrl+Space Space`, use `g`/`G` and movement, select with `v`, copy with `c`/`y` |
| Native Ghostty escape hatch | Hold `Shift` while dragging, then use the existing Ghostty/OS copy shortcut |
| Entire visible terminal surface | Ghostty Select All if desired, but it is not tmux-pane-aware |
| Paste from OS clipboard | Existing Ghostty/OS paste shortcut |
| Paste from tmux buffer | `Ctrl+Space v` or `Ctrl+Space ]` |

Select All warning: Ghostty sees tmux as one terminal surface. Cmd/Super+A can
select the visible terminal/scrollback surface, but it cannot select only the
active tmux pane's complete history. Use tmux copy mode for pane-specific
history.

Clipboard security: tmux uses native OSC 52 through `set-clipboard external`.
That lets tmux copies reach Ghostty and then the macOS or Linux clipboard
without relying on `pbcopy`, `wl-copy`, `xclip`, or `xsel`. `external` is chosen
instead of `on` because it lets tmux write outward while preventing arbitrary
programs running inside tmux from creating tmux paste buffers through OSC 52.
Copying secrets still places them on the OS clipboard.

Reload and verify:

```bash
tmux source-file ~/.tmux.conf
tmux -V
tmux show -g prefix
tmux show -g prefix2
tmux show -s set-clipboard
tmux info | grep 'Ms:'
echo "$TERM"
```

If OSC 52 terminal capability changes do not apply to an existing tmux server,
start a new tmux server later. `tmux kill-server` forces a full restart but also
terminates every active tmux session, so do not run it casually.

Verification checklist:

| Check | Expected result |
|---|---|
| `Ctrl+Space d` | Detaches tmux |
| `Ctrl+B d` | Still detaches tmux |
| `Ctrl+Space Space` | Enters pane copy mode |
| `v`, move, `c` | Copies selection to tmux buffer and OS clipboard |
| `v`, move, `y` | Same as `c`, for Vim/Neovim muscle memory |
| `Ctrl+Space v` | Pastes the tmux buffer |
| Mouse drag in tmux | Pane-aware tmux selection/copy behavior |
| `Shift+drag` | Ghostty-native selection bypassing tmux |
| `Ctrl+C` at a running command | Still interrupts the process |

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
| `Ctrl+Space c` | New window |
| `Ctrl+Space n` / `p` | Next / previous window |
| `Ctrl+Space Tab` | Last window |
| `Ctrl+Space 0-9` | Jump to window number |
| `Ctrl+Space w` | Choose window |
| `Ctrl+Space ,` | Rename current window |
| `Ctrl+Space X` | Kill current window with confirmation |
| `Ctrl+Space d` | Detach session |
| `Ctrl+Space r` | Reload tmux config |

Window numbers start at `1` and renumber automatically after windows are closed,
matching the OS workspace habit better than tmux's default `0`-based numbering.

Pane and window layout:

| Keys | Does |
|---|---|
| `Ctrl+Space Space` | Enter copy mode; use `Ctrl+Space :next-layout` for layout cycling |
| `Ctrl+Space H/J/K/L` | Resize pane left/down/up/right; repeat without prefix for a short window |
| `Ctrl+Space {` / `}` | Move pane left / right in the layout |
| `Ctrl+Space !` | Break pane out into its own window |
| `Ctrl+Space :join-pane -t :1` | Move current pane into window 1 |
| `Ctrl+Space :swap-window -s 2 -t 1` | Swap window 2 with window 1 |

Scrollback and copy mode:

| Keys | Does |
|---|---|
| `Ctrl+Space Space` / `Ctrl+Space [` | Enter copy/scrollback mode |
| `q` | Exit copy mode |
| `v` | Start selection in copy mode |
| `V` | Select line in copy mode |
| `c` / `y` / `Enter` | Copy selection in copy mode |
| `Ctrl+Space v` / `Ctrl+Space ]` | Paste tmux buffer |
| `Ctrl+Space =` | Choose a paste buffer |

In Ghostty on macOS, use tmux windows instead of Ghostty tabs when running under
AeroSpace. This avoids native tab/window-manager edge cases while keeping
terminal tabs.

Recommended project pattern:

```bash
t
# Create tmux windows with Ctrl+Space c, rename with Ctrl+Space ,.
# Detach with Ctrl+Space d; later cd back to the project and run: t
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
