# Task 22 — macOS documentation

Status: done
Scope: repo-only
Depends on: none (richer if 07/13/17/21 are done; write what exists, stub the rest)
Size: S

## Objective
Two documents: a first-time setup runbook and the lamac reference page.
Existing docs updated to mention the macOS layers.

## Files involved
- `docs/macos-first-time-setup.md` (new)
- `docs/macos-personal.md` (new or extend — tasks 17/21 may have seeded sections)
- `docs/where-to-edit.md`, `docs/README.md` (add macOS entries)

## Reason
The repo's docs are the rebuild contract; a wiped Mac must be recoverable
from them alone.

## Proposed implementation
`macos-first-time-setup.md` (ordered):
1. Install Homebrew (brew.sh) — the one manual prerequisite
2. `bash -c "$(curl -fsSL <raw bootstrap url>)"` or clone + `./bootstrap.sh`
3. Rename machine if fresh (`scutil` commands, task 01)
4. Login round: Tailscale.app, `atuin login && atuin sync`, GitHub SSH
   (`dotfiles git setup-ssh`)
5. Services: `brew services start felixkratz/formulae/borders` and sketchybar
6. Grant permissions: AeroSpace + Rectangle (Accessibility), SketchyBar/
   Spotify AppleScript (Automation) — first-run prompts, list them so they're
   expected
7. `dotfiles status && dotfiles doctor`
`macos-personal.md` sections: layer map for lamac; terminal = Ghostty (+ why
kitty/alacritty status); AeroSpace + Rectangle coexistence (AeroSpace owns
tiling/workspaces, Rectangle only for ad-hoc snapping of floating windows —
keep their hotkeys disjoint, list both sets); Raycast conventions; wallpapers
shared-vs-local + rotation opt-in; notable defaults (task 21 table); AI
tooling notes (Ollama.app owns CLI + models, `~/.ollama` never committed; LM
Studio optional); what is deliberately NOT automated (defaults beyond the
table, Keychain/iCloud, MAS, VS Code — Settings Sync owns it, browser
profiles, Raycast/KM data).

## Safety concerns
Docs must not embed tokens, IPs beyond what's already in tracked ssh config,
or personal data. Keep the bootstrap URL the canonical raw GitHub one.

## Validation commands
```bash
grep -rn 'wezterm\|minidlna' docs/ | grep -vi 'removed\|legacy'   # empty
# Read-through: another agent should be able to execute setup start to finish.
```

## Rollback notes
Docs-only; revert.

## Acceptance criteria
A fresh-Mac rebuild is executable from macos-first-time-setup.md alone;
macos-personal.md answers "where do I edit X for the Mac" for every managed
piece.

## Result
Added docs/macos-first-time-setup.md, expanded docs/macos-personal.md with the
lamac layer map and managed surfaces, and linked macOS docs/layers from README
and where-to-edit. Validation grep for unwanted WezTerm/minidlna references is
clean except explicit removed/legacy wording.
