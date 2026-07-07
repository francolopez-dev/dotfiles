# Task 29 — Final review and push

Status: todo
Scope: repo-only
Depends on: task-28
Size: S

## Objective
The whole macos-lamac series is reviewed as one body of work and pushed to
origin/main. This is the ONLY task that pushes.

## Files involved
- `.repo/TODO.md` (close out resolved items)
- `backlog/macos-lamac/README.md` (final checklist state)

## Reason
Franco's workflow: many small local commits by different agents/models, one
deliberate push at the end.

## Proposed implementation
1. `git log --oneline <first-backlog-commit>..HEAD` — every commit maps to a
   task, message style consistent; no fixup noise worth cleaning (if there is,
   ask Franco before any history rewrite — default is push as-is).
2. `git diff <first-backlog-commit>..HEAD --stat` — nothing outside the
   expected areas (scripts/, packages/, stow/, docs/, backlog/, .githooks,
   .gitignore, .stowrc, tests/).
3. Secrets sweep over the whole range:
   `git diff <first>..HEAD | grep -cE 'PRIVATE KEY|ghp_|xox[bap]-|AKIA'` -> 0.
4. Update `.repo/TODO.md`: mark the wallpaper-management and Ollama/LM-Studio
   items resolved (point at docs/macos-personal.md); leave unrelated items.
5. Confirm all backlog tasks show `Status: done` and tick the README index.
6. `git push origin main`.
7. On the other machines, at next convenience: `dotfiles update`.

## Safety concerns
Push only from a green state: tasks 01-28 done, task 28's evidence recorded.
Never force-push. If origin has moved, `git pull --ff-only` first and re-run
the secrets sweep.

## Validation commands
```bash
git log origin/main..HEAD --oneline | wc -l   # the series, pre-push
git push origin main
git status -sb    # clean, in sync
```

## Rollback notes
Pushed commits are public to the repo's consumers (your machines): prefer a
forward fix (`git revert <sha>`) over any history rewrite after push.

## Acceptance criteria
origin/main contains the series; TODO.md updated; backlog index fully
checked; no secrets in the pushed range.
