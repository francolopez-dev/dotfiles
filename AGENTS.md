# AGENTS.md
## RESPONSES

- Keep responses concise and to the point - unless the user asks otherwise

## PLANNING MODE

- Always ask clarifying questions
- Never assume design, tech stack or features
- Use deep-dive sub-agents to assist with research
- Use deep-dive sub-agents to review the different aspects of your plan before presenting to the user

## CHANGE / EDIT MODE

- Never implement features yourself when possible - use sub-agents!
- Identify changes from the plan that can be implemented in parallel, and use sub-agents to implement the features efficiently
- When using sub-agents to implement features, act as a coordinator only
- Use the best model for the task - premium models for complex tasks (like coding) and mid-tier models for simpler tasks, like documentation
- After completing features (large or small), always run commands like lint, type check and next build to check code quality

## TESTING

- Use any testing tools, libraries available to the project for testing your changes
- Never assume your changes simply work, always test!
- If the project does not have any testing tools, scripts, MCP tools, skills, etc. available for testing, ask the user whether testing should be skipped.

## UI DESIGN

- Always follow the UI design system when creating or reviewing components or pages.
- Design System: @DESIGN.md

## Repo Shape
- This is a Bash/GNU Stow dotfiles platform, not a package-manager app repo; there is no root `package.json`, Makefile, or CI workflow.
- Day-to-day user entrypoint is `stow/scripts/bin/dotfiles`; keep it a thin dispatcher and put real behavior in `scripts/*.sh`.
- Installer/recovery entrypoints are `scripts/bootstrap.sh` for remote `curl | bash` and root `./bootstrap.sh` for local orchestration.
- Root `./bootstrap.sh` order is fixed: `detect-os -> select-profile -> validate-profiles -> install-packages -> validate-installed-packages -> cleanup-stale-stow-links -> apply-stow -> configure-omarchy-terminal -> enable-services -> setup-syncing -> validate-terminal-integration`.

## Verification
- Run profile validation after any profile, package-group, stow-manifest, service, or sync-agent change: `scripts/validate-profiles.sh`.
- Run focused Bash harnesses directly: `tests/cli/run-tests.sh`, `tests/bootstrap-update/run-tests.sh`, `tests/stow-cleanup/run-tests.sh`, `tests/recovery-pack/run-tests.sh`.
- Recovery-pack tests require `age`, `age-keygen`, and `tar`; `restic` cases run only when `restic` is installed.
- Shell lint command used by project docs/plans: `shellcheck -x bootstrap.sh scripts/*.sh stow/scripts/bin/dotfiles tests/*/run-tests.sh`.
- Use `./bootstrap.sh --dry-run --profile minimal` or `dotfiles bootstrap --dry-run --profile minimal` for a low-risk orchestration smoke test.

## Profiles, Packages, And Stow
- Profiles live in `profiles/*.conf` and are sourced shell files with `PACKAGE_GROUPS`, `SERVICES`, optional `STOW_PACKAGES`, and optional `SYNC` arrays.
- Effective stow packages are `profiles/stow-base` plus the matching line in `profiles/stow-os-base` plus profile `STOW_PACKAGES`, then filtered by `profiles/stow-os.map`.
- Shared shell/app config belongs in `profiles/stow-base`; OS-wide desktop config belongs in `profiles/stow-os-base`; profile `STOW_PACKAGES` are only for genuinely profile-specific dotfiles.
- To add a profile, update both `profiles/<name>.conf` and `profile_os()` in `scripts/validate-profiles.sh`; also update the wizard choices in `scripts/select-profile.sh`.
- To add a service with a non-obvious unit name, map it in `scripts/enable-services.sh`; validate-profiles only allows known service names.
- To add a sync agent, update `scripts/setup-syncing.sh`, profile `SYNC=(...)`, and `known_sync_agent()` in `scripts/validate-profiles.sh`.

## Safety Gotchas
- Never commit secrets or machine-local state; `.gitignore` blocks `*.local`, `*.age`, logs, recovery artifacts, and `.config/dotfiles/profile`.
- Stow conflicts are intentionally non-destructive: interactive runs prompt, non-interactive runs skip, `--backup-conflicts` backs up to `~/.dotfiles-backup/<timestamp>/`, and `--adopt` requires reviewing `git diff` afterward.
- Generic Arch is not accepted as Omarchy unless Omarchy markers exist or `DOTFILES_ASSUME_OMARCHY=1` is set.
- For remote bootstrap env vars, place env on `bash` after the pipe, e.g. `curl .../scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash bash`; `VAR=... curl ... | bash` is ignored by Bash and falls back to safe mode.
- `dotfiles update --reset` and remote reset mode are destructive and require explicit confirmation (`--confirm` or `DOTFILES_CONFIRM_RESET=1`).

## Desktop Notes
- Omarchy desktop config lives mainly in `stow/hypr`, `stow/waybar`, `stow/rofi`, `stow/wallpapers`, and `stow/themes`; these are OS-base packages, not per-profile extras.
- After Waybar edits, use `dotfiles desktop reload waybar` rather than manually killing processes when possible.
