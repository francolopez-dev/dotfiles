# macOS app & brew audit

Snapshot taken 2026-06-23 on the Mac. Goal: keep only what you actually use.
The **Keep** set is already seeded into [`packages/os-macos.list`](../packages/os-macos.list).
Review the **Remove?** and **Duplicate** items, then prune the list and run
`brew uninstall` for anything you drop.

## Remove (recommended)

| Package | Why |
|---|---|
| `wezterm` (cask) | Replaced by Ghostty/Alacritty; purged from the repo. |
| `fig` (cask) | Discontinued (became Amazon Q); dead tool. |
| `jiggler` (cask) | Mouse jiggler — keep only if you actually need it. |

## Duplicates — pick one

| Group | Installed | Suggestion |
|---|---|---|
| Docker | `docker` (formula), `docker` (cask), `docker-desktop` | Keep `docker-desktop` (or colima); drop the rest. |
| Autodesk Fusion | `autodesk-fusion`, `autodesk-fusion360` | Keep one. |
| HandBrake | `handbrake`, `handbrake-app` | Keep `handbrake` (CLI) or the app, not both. |
| Terminals | `alacritty`, `kitty`, `wezterm` | Keep `alacritty`; drop `kitty` + `wezterm`. |
| Window mgmt | `aerospace`, `rectangle` | `aerospace` is the keeper; `rectangle` is redundant. |

## Review — keep only if used

Browsers: `opera`, `tor-browser` (you also have Firefox + Chrome).
AI/dev: `codex` (cask), `opencode` (formula), `opencode-desktop`, `anomalyco/tap/opencode`.
Media/torrent: `steam`, `jdownloader`, `qbittorrent`, `httrack`, `rar`.
Misc apps: `keyboard-maestro`, `thonny`, `flux-markdown`, `xnviewmp`, `wkhtmltopdf`,
`taskell`, `synergy-core`, `mailsy`, `telnet`, `cdrtools`, `wifi-password`.

## Likely transitive deps (showing as leaves)

These are usually pulled in by other packages — verify before removing:
`adwaita-icon-theme`, `ata`, `bzip2`, `expat`, `gtkmm3`, `icu4c@76`, `jsoncpp`,
`libiconv`, `lzip`, `nanorc`, `pcre`, `pip-tools`, `pipenv`, `popeye`, `qrencode`,
`resvg`, `spdlog`, `zlib`.

## Notes

- `aerospace` config is managed in `stow/os-macos/aerospace/`.
- `borders` (JankyBorders) config is in `stow/os-macos/borders/` — keep if you
  still run it alongside aerospace, otherwise remove the stow package too.
- Reconcile after pruning: `brew bundle dump` can help compare, or just
  `brew leaves` / `brew list --cask` vs this list.
