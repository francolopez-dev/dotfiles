# Task 24 — lamac cleanup 1/3: dangling flat-layout symlinks

Status: done
Scope: mac-local (run on lamac, human present)
Depends on: task-01
Size: S

## Objective
Zero symlinks in `$HOME` point at the deleted flat stow layout. Every removal
is recorded in a manifest first.

## Files involved
None in repo. On lamac: the dangling links listed in CONTEXT.md, plus
`~/.config/dotfiles/profile` (dead mechanism), manifest at
`~/.dotfiles-backup/legacy-<timestamp>/dangling-manifest.txt`.

## Reason
Clean slate: these links are broken (targets deleted by commit cedc5d2) and
would flood the stow conflict wizard during first apply.

## Proposed implementation
```bash
ts=$(date +%Y-%m-%d-%H%M%S); mkdir -p ~/.dotfiles-backup/legacy-$ts
# manifest: every dangling link whose target contains "dotfiles/stow/"
find "$HOME" -maxdepth 1 -type l ! -exec test -e {} \; -print
find "$HOME/.config" "$HOME/.ssh" -maxdepth 3 -type l ! -exec test -e {} \; -print
```
For each result: confirm `readlink` contains `dotfiles/stow/`; append
`<link> -> <target>` to the manifest; then `rm` the link. Do NOT touch links
that resolve, and nothing that isn't a symlink. Then back up + remove
`~/.config/dotfiles/profile` (real file, 15 bytes, dead mechanism). Remove
now-empty dirs only if they held nothing else (`rmdir`, never `rm -r`):
`~/.config/wezterm` `~/.config/borders` `~/.config/git` `~/.config/btop`.

## Safety concerns
`~/.ssh/config.local`, keys, `known_hosts` are real files — untouched by the
symlink filter, but eyeball every line of the manifest before deleting.
`rm` only paths present in the manifest.

## Validation commands
```bash
find "$HOME" -maxdepth 1 -type l ! -exec test -e {} \; | wc -l          # 0
find "$HOME/.config" "$HOME/.ssh" -maxdepth 3 -type l ! -exec test -e {} \; | wc -l  # 0
wc -l ~/.dotfiles-backup/legacy-*/dangling-manifest.txt                  # ~15
zsh -ic 'echo shell-ok'    # shell still opens (it was already degraded; no worse)
```

## Rollback notes
Links pointed at nothing, so removal loses nothing; the manifest allows exact
recreation (`ln -s <target> <link>`) if ever needed.

## Acceptance criteria
Both find commands return 0; manifest saved; ssh keys/config.local untouched
(`ls -la ~/.ssh` unchanged except the removed `config` link).

## Result
Completed on lamac. Backup dir:
`~/.dotfiles-backup/legacy-2026-07-07-211258/`. Manifest has 22 entries
including the dead profile marker. Both dangling-link find checks return 0;
`~/.ssh` real files and `config.local` are untouched; `zsh -ic 'echo shell-ok'`
works.
