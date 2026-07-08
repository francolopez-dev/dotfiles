# Task 26 — lamac cleanup 3/3: unwanted services and apps

Status: done
Scope: mac-local (run on lamac, human present)
Depends on: task-24
Size: S

## Objective
minidlna, the stale ollama LaunchAgent, and WezTerm are gone from lamac.

## Files involved
On lamac only: `~/Library/LaunchAgents/homebrew.mxcl.minidlna.plist`,
`~/Library/LaunchAgents/homebrew.mxcl.ollama.plist`, WezTerm cask + app,
`~/.config/wezterm` (already emptied by task 24 — verify).

## Reason
Franco's decisions: minidlna unwanted; the ollama plist is stale (the brew
formula is uninstalled — Ollama.app owns `/usr/local/bin/ollama`); WezTerm is
replaced by Ghostty.

## Proposed implementation
```bash
brew services stop minidlna 2>/dev/null || true
brew uninstall minidlna
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.ollama.plist 2>/dev/null || true
rm ~/Library/LaunchAgents/homebrew.mxcl.ollama.plist
brew uninstall --cask wezterm     # also removes WezTerm.app
```
Verify Ollama.app itself still works (it is wanted): `ollama --version`.
Do NOT touch: kitty, borders, sketchybar, synergy, jiggler, or anything else
in LaunchAgents.

## Safety concerns
`brew services stop` before uninstall so the plist is cleaned by brew, not
left behind. Double-check the exact plist filenames with
`ls ~/Library/LaunchAgents` before rm — remove only the two named above.

## Validation commands
```bash
brew services list | grep -E 'minidlna|started.*error' || echo services-clean
ls ~/Library/LaunchAgents | grep -E 'minidlna|ollama' || echo agents-clean
[ ! -d /Applications/WezTerm.app ] && echo wezterm-gone
ollama --version    # still works (app-owned)
```

## Rollback notes
`brew install minidlna && brew services start minidlna`;
`brew install --cask wezterm`. The ollama plist regenerates only if the
formula is reinstalled — that is fine.

## Acceptance criteria
All three validation greps clean; Ollama.app CLI unaffected; no other
LaunchAgents removed.

## Result
Completed on lamac. `minidlna` was no longer installed as a formula but its
LaunchAgent was removed; stale `homebrew.mxcl.ollama.plist` removed; WezTerm
cask uninstalled and `/Applications/WezTerm.app` removed. Homebrew autoremoved
four now-unused dependencies. Validation: services-clean, agents-clean,
wezterm-gone, and `ollama --version` reports 0.13.1.
