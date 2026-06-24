# Terminal UX

Terminal-first workflow notes for Omarchy systems. Zsh remains the default
interactive shell; bash sources the same shared aliases before handing off to
zsh.

## Audit

| Area | Current tool | Current config | Problem | Recommendation |
|---|---|---|---|---|
| Terminal | Ghostty | `stow/global/ghostty/.config/ghostty/config` plus profile overrides | Good base; only supported keys should be used | Keep Ghostty primary, validate with `ghostty +validate-config` |
| Shell | zsh + oh-my-zsh | `stow/global/zsh/.zshrc` | No issue; default should not change | Keep zsh default |
| Bash | bash compatibility shell | `stow/global/bash/.bashrc` | Immediately execs zsh for interactive shells | Keep bash aliases in shared file so non-zsh sessions still work |
| Aliases | shared shell aliases | `stow/global/shell/.config/shell/aliases.sh` | `ll` was minimal and no `l`, `la`, `L`, `lt` | Use eza aliases with safe `ls` fallbacks |
| Directory listing | eza | package in `packages/global.list` | Defaults were underused | Use long header, icons, git, relative time, directories first |
| Colors | eza defaults + terminal theme | no custom `LS_COLORS` | `vivid` is not installed; custom colors add maintenance | Keep eza defaults for now; revisit `vivid` only if colors are not readable |
| Prompt | Powerlevel10k | `stow/global/zsh/.p10k.zsh` | Already configured; Starship also installed but unused | Do not add another prompt framework |
| History | Atuin | `stow/os-omarchy/atuin/.config/atuin/config.toml` | Good compact fuzzy host-filtered setup | Keep as-is |
| Navigation | zoxide | initialized in `stow/global/zsh/.zshrc` | zsh-only init today | Keep; add bash init later only if bash becomes interactive |
| File manager | yazi | package + `alias y='yazi'`; placeholder config | No custom config yet | Keep simple until a concrete yazi workflow need appears |
| Editor | Neovim LazyVim | `stow/os-omarchy/neovim/.config/nvim/` | Good starter config | Keep as-is |
| Opencode | none found | none | No repo config present | Do not add config without a concrete need |
| Fonts | Nerd fonts installed | Ghostty global/profile configs | Global config lists JetBrains/Fira fallback | Keep Nerd Font support for icons |
| Themes | Catppuccin Mocha | Ghostty theme | Fits dark low-strain direction | Keep Catppuccin/Dracula direction |

## Directory Listing

The shared aliases use `eza` when available and fall back to `ls` on minimal
servers.

| Command | Purpose |
|---|---|
| `l` | Pretty long listing with headers, icons, git status, relative time |
| `ll` | Same as `l` |
| `la` | Pretty long listing including hidden files |
| `L` | Capital Omerxx-inspired pretty long listing |
| `lt` | Two-level tree with icons and git status |
| `y` | Open yazi file manager |
| `z` | Zoxide jump command after shell init |
| `atuin` | Shell history search and sync tool |

## Bash And Zsh Alias Cheatsheet

These aliases live in `stow/global/shell/.config/shell/aliases.sh` and are
sourced by both `stow/global/bash/.bashrc` and `stow/global/zsh/.zshrc`.

| Alias | Expands to | Description |
|---|---|---|
| `..` | `cd ..` | Go up one directory |
| `gs` | `git status` | Show repo status |
| `gp` | `git pull` | Pull current branch |
| `dps` | `docker ps` | List running containers |
| `dcu` | `docker compose up -d` | Start compose stack in background |
| `dcd` | `docker compose down` | Stop compose stack |
| `ff` | `fastfetch 2>/dev/null || true` | Show system summary without shell noise |
| `v` | `nvim` | Open Neovim |
| `y` | `yazi` | Open yazi |
| `l` | `eza --long ...` or `ls -lh` fallback | Pretty long listing |
| `ll` | `eza --long ...` or `ls -lah` fallback | Pretty long listing |
| `la` | `eza --long --all ...` or `ls -lah` fallback | Pretty all-files listing |
| `L` | `eza --long ...` or `ls -lh` fallback | Omerxx-inspired table listing |
| `lt` | `eza --tree --level=2 ...` or `ls -lah` fallback | Small tree view |
| `cls` | `clear && printf "\e[3J"` | Clear visible screen and scrollback |

## Terminal Visual Style

Ghostty is configured in `stow/global/ghostty/.config/ghostty/config` with
machine-specific overrides in
`stow/profile-<hostname>-omarchy/ghostty/.config/ghostty/profile-overrides`.

Current direction:

- Theme: `Catppuccin Mocha`
- Fonts: Nerd Font capable family for file icons
- Background: dark, slightly transparent, blur enabled where the desktop supports it
- Window: no client decoration on Omarchy
- Cursor: bar cursor, click-to-move enabled, mouse hides while typing
- Copy/paste: Super/Cmd style keybindings

Ghostty 1.3.1 supports `background-blur`, but does not expose a
`background-blur-radius` key. It also does not provide a native cursor trail or
smooth cursor drag setting. Do not add unsupported keys.

Validate after edits:

```bash
ghostty +validate-config --config-file=stow/global/ghostty/.config/ghostty/config
ghostty +show-config 2>/dev/null || true
```

## Optional Tools Inspired By Omerxx

| Tool | What it adds | Fit for my workflow | Maintenance cost | Recommendation |
|---|---|---|---|---|
| Nushell | Native table pipeline output like `# name type size modified` | Useful to explore, but not as default shell | Medium; different language and startup model | Optional exploration only; keep zsh default |
| Starship | Cross-shell prompt | Not needed while p10k is configured | Low-medium, but duplicate prompt framework | Do not add unless replacing p10k later |
| Television | Fast fuzzy TUI picker | Could complement launcher/search workflows | Medium | Wait for concrete workflow need |
| Zellij | Terminal workspace manager | You prefer Ghostty with tmux optional | Medium | Do not add by default |
| Tmux | Persistent terminal sessions | Already global package | Low | Keep optional; improve only when needed |
| gh-dash | GitHub dashboard TUI | Useful if GitHub triage becomes daily | Low-medium | Optional, not baseline |
| Yazi improvements | Better file-manager previews/actions | Fits terminal-first workflow | Low-medium | Add only when a workflow is defined |
| Atuin improvements | Better shell history and sync | Already fits | Low | Keep current compact config |

## Manual Tests

```bash
dotfiles update
exec zsh
l
L
la
lt
ghostty --version
ghostty +show-config 2>/dev/null || true
```

Check that colors are readable, permissions are identifiable, directories,
files, symlinks, executables, archives, images, and git status are visually
distinct, Ghostty opens without config errors, and shell startup remains clean.
