# scripts stow package

Files placed under `bin/` here are symlinked into `~/bin` (added to PATH by
`stow/global/shell/.config/shell/env.sh`). Put small personal shell scripts here.

`bin/dotfiles` is the unified day-to-day entrypoint for this repo. Add new
platform commands there as subcommands instead of creating standalone
`dotfiles-*` scripts.
