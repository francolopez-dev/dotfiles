# Atuin Shell History

Atuin is the managed shell-history tool on macOS and Omarchy. It records
commands locally, gives a better searchable history UI, and can sync encrypted
history across personal machines.

This repo manages only the safe config file:

```text
stow/global/atuin/.config/atuin/config.toml
```

Atuin secrets and state stay outside Git in `~/.local/share/atuin/`. The
encrypted recovery pack includes the Atuin key, session, and local database when
present.

## Where It Runs

| System | Default |
|---|---|
| macOS | installed with Homebrew, zsh integration enabled |
| Omarchy | installed with pacman, zsh integration enabled |
| Debian/Ubuntu servers | not installed by default; personal-server opt-in only |
| Work servers | plain shell history only |

When `atuin` is installed, zsh initializes it automatically and Atuin owns
`Ctrl+R`. Fzf still owns file and directory picking with `Ctrl+T` and `Alt+C`.

## First Setup

On the first personal machine, create an account:

```bash
atuin register -u <username> -e <email>
atuin key
atuin sync
```

Store the printed Atuin key in Vaultwarden and the encrypted recovery pack. The
Atuin team cannot recover synced history without it.

On every additional personal Mac or Omarchy machine:

```bash
atuin login -u <username>
atuin sync
```

After login, open a new shell or run `exec zsh` so the shell hook is active.

## Personal Servers

Servers stay minimal by default. Use Atuin only on personal Debian/Ubuntu
servers where synced shell history is acceptable.

Manual install on a personal server:

```bash
sudo apt update
sudo apt install atuin
exec zsh
atuin login -u <username>
atuin sync
```

If `atuin` is not available in that server's stock apt repositories, leave it
uninstalled unless you intentionally create a per-host package/profile exception.
Do not install Atuin or enable external history sync on work servers.

## Daily Use

| Command or key | Use it for |
|---|---|
| `Ctrl+R` | Open interactive Atuin history search |
| type search text | Fuzzy-search commands |
| `Ctrl+R` inside Atuin | Cycle filters such as global, host, session, directory, and workspace |
| `Tab` | Insert selected command into the prompt for editing |
| `Enter` | Execute selected command immediately, because `enter_accept = true` |
| `Esc` or `Ctrl+C` | Close search without running a command |
| `atuin register -u <username> -e <email>` | Create the first sync account |
| `atuin login -u <username>` | Log in on another personal machine |
| `atuin logout` | Remove the server session from this machine |
| `atuin status` | Show login/sync status |
| `atuin sync` | Sync now |
| `atuin sync -f` | Force a full sync when history looks incomplete |
| `atuin key` | Print the local encryption key; treat as a secret |
| `atuin stats` | Show command statistics |
| `atuin search <query>` | Search history from the command line |
| `atuin history list` | List recorded commands |
| `atuin history last` | Print the last recorded command |
| `atuin history dedup` | Remove exact duplicate history entries |
| `atuin history prune` | Delete history entries matching configured filters |
| `atuin import auto` | Import existing shell history after first install |
| `atuin doctor` | Check common Atuin setup problems |
| `atuin info` | Show config/data locations and environment details |
| `atuin default-config` | Print Atuin's full default config reference |
| `atuin account change-password` | Change the sync account password |
| `atuin account delete` | Delete the sync account and all synced server data |
| `atuin dotfiles ...` | Do not use here; this repo owns shell aliases and config |

## What Gets Recorded

Atuin records the command, working directory, timestamp, duration, exit code,
hostname, username, and shell session. The managed config enables Atuin's
built-in `secrets_filter` and ignores commands that start with a space.

Use a leading space for anything sensitive:

```bash
 export TOKEN=temporary-value
```

Do not rely only on filters. Long-lived credentials belong in Vaultwarden or
machine-local ignored files such as `~/.config/shell/env.local`.

## Managed Defaults

| Setting | Value | Reason |
|---|---|---|
| `search_mode` | `fuzzy` | Fast forgiving search |
| `filter_mode` | `host` | Start with this machine's history first |
| `style` | `compact` | Fits terminal/tmux panes well |
| `inline_height` | `20` | Keeps context visible |
| `show_preview` | `true` | Shows long commands before running |
| `enter_accept` | `true` | Enter runs the selected command |
| `keymap_mode` | `auto` | Matches shell keymap when possible |
| `store_failed` | `true` | Failed commands are useful for debugging |
| `secrets_filter` | `true` | Drop common token/key patterns |
| `workspaces` | `true` | Git repo-aware history for project work |
| `history_filter` | `^\\s` | Leading-space commands are skipped |

The UI includes a `host` column so synced history from Mac, Omarchy, and
personal servers remains understandable.

## Recovery

The recovery pack collects these Atuin files when present:

```text
~/.local/share/atuin/key
~/.local/share/atuin/session
~/.local/share/atuin/history.db
```

These files must never be committed. `key` decrypts synced history, `session` is
effectively an API token, and `history.db` contains local command history.

After registering Atuin, logging in on a new machine, or rotating the Atuin key,
send a fresh pack:

```bash
dotfiles recovery send
```

## Troubleshooting

| Problem | Try |
|---|---|
| `Ctrl+R` still opens fzf | confirm `command -v atuin`, then `exec zsh` |
| Not logged in | `atuin login -u <username>` |
| Missing synced commands | `atuin sync -f` |
| Unsure which config is active | edit `stow/global/atuin/.config/atuin/config.toml`, then `dotfiles apply` |
| Need plain local history on a server | do not install Atuin; zsh/bash history keeps working |
