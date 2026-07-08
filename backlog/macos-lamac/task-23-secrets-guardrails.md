# Task 23 — Secrets guardrails in pre-commit

Status: done
Scope: repo-only
Depends on: none (coordinates with task 16, which also edits the hook)
Size: S

## Objective
A staged private key or obvious token cannot be committed to this repo.

## Files involved
- `.githooks/pre-commit` (extend; it currently only runs validate-bootstrap.sh,
  and task 16 adds a wallpaper check — append a secrets section)
- `.gitignore` (additions)

## Reason
Clean-slate migration moves many files around `$HOME`; one careless `git add`
of an adopted config must not leak key material. Repo rule: secrets never live
in git.

## Proposed implementation
Pre-commit, over `git diff --cached` content (not the working tree):
- Block on private-key headers, GitHub `ghp_` tokens, Slack `xox...` tokens,
  AWS access key IDs, and age secret keys.
- Block staged paths under `stow/**/.ssh/` other than the known `config` file
- Print the offending file+pattern and how to bypass intentionally
  (`git commit --no-verify`) so false positives don't wedge work.
Keep it bash-3.2-safe (runs on the Mac). `.gitignore` additions:
`**/raycast/`, `.ollama/`, `*.plist.bak`.

## Safety concerns
False positives are acceptable; silent false negatives are not — prefer broad
patterns with the documented bypass. Do not scan file contents of binaries
(guard with `git diff --cached --numstat` binary detection or extension list).

## Validation commands
```bash
bash .githooks/pre-commit   # clean tree passes
printf '%s\n' '-----BEGIN OPENSSH ''PRIVATE KEY-----' > /tmp/fakekey && \
  cp /tmp/fakekey stow/global/git/fake.txt && git add stow/global/git/fake.txt && \
  bash .githooks/pre-commit; echo "exit=$? (want nonzero)"; \
  git reset -q stow/global/git/fake.txt && rm stow/global/git/fake.txt /tmp/fakekey
```

## Rollback notes
Revert; hook is additive.

## Acceptance criteria
Negative test blocks with a clear message; normal commits unaffected; hook
runs under macOS /bin/bash 3.2.

## Result
Extended .githooks/pre-commit with staged-path SSH material blocking and
staged-content token/private-key scans, skipping binary blobs. Added ignore
entries for raycast data, .ollama, and plist backups. Negative private-key test
blocks with bypass guidance; clean hook path passes.
