# Git and GitHub cheatsheet

Simple commands for maintaining this dotfiles repo.

## Daily status

```bash
cd ~/dotfiles
git status --short --branch
git log --oneline -5
```

Use this before changing files. A clean repo shows no changed files.

## Get latest changes

```bash
cd ~/dotfiles
git pull --ff-only
```

If the repo is stuck in detached HEAD:

```bash
cd ~/dotfiles
git fetch origin main
git switch main
git pull --ff-only
```

## Save your changes

```bash
cd ~/dotfiles
git status --short
git diff
git add path/to/file
git commit -m "short: explain the change"
git push
```

Use a short commit message, for example:

```bash
git commit -m "bootstrap: fix fresh omarchy install"
git commit -m "docs: add git cheatsheet"
git commit -m "hyprland: tune fornax monitor"
```

## See what changed

```bash
git diff
git diff --name-only
git diff --staged
```

## Undo safely

Unstage a file but keep the edit:

```bash
git restore --staged path/to/file
```

Discard your edit to one file:

```bash
git restore path/to/file
```

Do not use `git reset --hard` unless you are intentionally deleting local work.

## Stash temporary work

```bash
git stash push -u -m "temporary work"
git stash list
git stash show --stat stash@{0}
git stash pop
```

## Branches

Create a branch:

```bash
git switch -c my-change
```

Switch back to main:

```bash
git switch main
git pull --ff-only
```

Delete a local branch after it is no longer needed:

```bash
git branch -d my-change
```

## GitHub SSH

GitHub password authentication over HTTPS does not work. Use SSH for pushing.

```bash
ssh-keygen -t ed25519 -C "email@example.com"
cat ~/.ssh/id_ed25519.pub
```

Add the public key in GitHub: Settings -> SSH and GPG keys -> New SSH key.

Then switch this repo to SSH:

```bash
cd ~/dotfiles
git remote set-url origin git@github.com:jfrancolopez/dotfiles.git
ssh -T git@github.com
```

Expected SSH success text:

```text
Hi <username>! You've successfully authenticated...
```

## Fresh bootstrap

Normal command:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh | bash
```

If GitHub raw cache is stale, pin the exact commit from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/<commit-sha>/scripts/bootstrap.sh | bash
```

Find the latest local commit SHA:

```bash
cd ~/dotfiles
git rev-parse HEAD
```

## Check GitHub raw content

Verify what raw GitHub is serving before running bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh -o /tmp/bootstrap.sh
bash -n /tmp/bootstrap.sh
```

If unsure, use the commit-pinned bootstrap URL instead of the branch URL.
