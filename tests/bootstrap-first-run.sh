#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  printf 'fail: %s\n' "$*" >&2
  exit 1
}

real_git="$(command -v git)"
current_branch="$(git -C "$repo_dir" branch --show-current)"
[[ -n "$current_branch" ]] || current_branch=main

source_repo="$tmp_dir/source-repo"
git clone "$repo_dir" "$source_repo" >/dev/null 2>&1
while IFS= read -r -d '' tracked_file; do
  if [[ -e "$repo_dir/$tracked_file" ]]; then
    mkdir -p "$source_repo/$(dirname "$tracked_file")"
    cp -a "$repo_dir/$tracked_file" "$source_repo/$tracked_file"
  else
    git -C "$source_repo" rm -q --ignore-unmatch -- "$tracked_file"
  fi
done < <(git -C "$repo_dir" ls-files -z)
git -C "$source_repo" add -A
if ! git -C "$source_repo" diff --cached --quiet; then
  git -C "$source_repo" \
    -c core.hooksPath=/dev/null \
    -c user.name='Dotfiles Test' \
    -c user.email='dotfiles-test@example.invalid' \
    commit -m 'test fixture source snapshot' >/dev/null
fi

mkdir -p "$tmp_dir/bin" "$tmp_dir/home" "$tmp_dir/pacman-state" "$tmp_dir/pacman-sync"

cat >"$tmp_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF

cat >"$tmp_dir/bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_dir="${PACMAN_MOCK_STATE:?}"
case "${1:-}" in
  -Qq)
    [[ -e "$state_dir/${2:-}" ]]
    ;;
  -Q)
    if [[ -e "$state_dir/${2:-}" ]]; then
      printf '%s 1.0-1\n' "$2"
    else
      exit 1
    fi
    ;;
  -S|-Syu)
    if [[ "${1:-}" == "-Syu" && -n "${PACMAN_MOCK_SYNC_DIR:-}" ]]; then
      mkdir -p "$PACMAN_MOCK_SYNC_DIR"
      touch "$PACMAN_MOCK_SYNC_DIR/core.db"
    fi
    shift
    for arg in "$@"; do
      [[ "$arg" == --* ]] && continue
      touch "$state_dir/$arg"
    done
    if [[ "${PACMAN_MOCK_FAIL_ONCE:-0}" == "1" && ! -e "$state_dir/failed-once" ]]; then
      touch "$state_dir/failed-once"
      printf 'mock pacman: intentional nonzero after installing requested packages\n' >&2
      exit 1
    fi
    ;;
  *) exit 0 ;;
esac
EOF

cat >"$tmp_dir/bin/stow" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

cat >"$tmp_dir/bin/paru" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_dir="${PACMAN_MOCK_STATE:?}"
case "${1:-}" in
  -S)
    shift
    for arg in "$@"; do
      [[ "$arg" == --* ]] && continue
      touch "$state_dir/$arg"
    done
    ;;
  *) exit 0 ;;
esac
EOF

cat >"$tmp_dir/bin/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
real_git="$real_git"
if [[ "\
\${1:-}" == "clone" ]]; then
  dest=""
  url=""
  for arg in "\$@"; do
    case "\$arg" in
      http://*|https://*|file://*) url="\$arg" ;;
    esac
    dest="\$arg"
  done
  case "\$url" in
    https://github.com/ohmyzsh/ohmyzsh.git)
      mkdir -p "\$dest"
      printf '# mocked oh-my-zsh\n' >"\$dest/oh-my-zsh.sh"
      exit 0
      ;;
    https://github.com/zsh-users/zsh-autosuggestions.git|https://github.com/zsh-users/zsh-syntax-highlighting.git|https://github.com/romkatv/powerlevel10k.git)
      mkdir -p "\$dest"
      exit 0
      ;;
  esac
fi
exec "\$real_git" "\$@"
EOF

chmod +x "$tmp_dir/bin/sudo" "$tmp_dir/bin/pacman" "$tmp_dir/bin/stow" "$tmp_dir/bin/paru" "$tmp_dir/bin/git"
touch "$tmp_dir/pacman-state/brave-bin" "$tmp_dir/pacman-state/zen-browser-bin"

for run in 1 2; do
  output_file="$tmp_dir/bootstrap-run-$run.out"
  printf '==> bootstrap first-run fixture pass %s\n' "$run"
  if ! PATH="$tmp_dir/bin:$PATH" \
    PACMAN_MOCK_STATE="$tmp_dir/pacman-state" \
    PACMAN_MOCK_SYNC_DIR="$tmp_dir/pacman-sync" \
    PACMAN_MOCK_FAIL_ONCE=1 \
    HOME="$tmp_dir/home" \
    DOTFILES_DIR="$tmp_dir/home/dotfiles" \
    DOTFILES_PACMAN_SYNC_DIR="$tmp_dir/pacman-sync" \
    DOTFILES_REPO_URL="file://$source_repo" \
    DOTFILES_BOOTSTRAP_OS=omarchy \
    DOTFILES_BRANCH="$current_branch" \
    DOTFILES_STOW_CONFLICTS=backup \
      bash "$repo_dir/scripts/bootstrap.sh" </dev/null >"$output_file" 2>&1; then
    sed 's/^/  /' "$output_file"
    fail "bootstrap fixture pass $run failed"
  fi
  if [[ "${DOTFILES_FIXTURE_VERBOSE:-0}" == "1" ]]; then
    sed 's/^/  /' "$output_file"
  fi

  if [[ $run -eq 1 ]]; then
    grep -Fq 'pacman prerequisite install returned: 1' "$output_file" || fail 'missing pacman nonzero checkpoint'
    grep -Fq 'Pacman sync databases are missing; syncing before installing prerequisites' "$output_file" || fail 'missing pacman sync database checkpoint'
    grep -Fq 'bootstrap prerequisites present after pacman' "$output_file" || fail 'missing pacman package verification checkpoint'
    grep -Fq 'mock pacman: intentional nonzero after installing requested packages' "$output_file" || fail 'missing intentional pacman mock failure checkpoint'
    if grep -Fq 'bash: line 143: symlink: No such file or directory' "$output_file"; then
      fail 'fixture leaked stale symlink error'
    fi
  fi

  [[ -d "$tmp_dir/home/dotfiles/.git" ]] || fail 'dotfiles repo was not cloned'
  [[ -L "$tmp_dir/home/.local/bin/dotfiles" ]] || fail 'dotfiles CLI was not linked'
  [[ -r "$tmp_dir/home/.oh-my-zsh/oh-my-zsh.sh" ]] || fail 'Oh My Zsh was not installed'
done

mkdir -p "$tmp_dir/success-home" "$tmp_dir/pacman-success-state" "$tmp_dir/pacman-success-sync"
touch "$tmp_dir/pacman-success-state/brave-bin" "$tmp_dir/pacman-success-state/zen-browser-bin"
success_output="$tmp_dir/bootstrap-success.out"
printf '==> bootstrap first-run fixture pass pacman-success\n'
if ! PATH="$tmp_dir/bin:$PATH" \
  PACMAN_MOCK_STATE="$tmp_dir/pacman-success-state" \
  PACMAN_MOCK_SYNC_DIR="$tmp_dir/pacman-success-sync" \
  PACMAN_MOCK_FAIL_ONCE=0 \
  HOME="$tmp_dir/success-home" \
  DOTFILES_DIR="$tmp_dir/success-home/dotfiles" \
  DOTFILES_PACMAN_SYNC_DIR="$tmp_dir/pacman-success-sync" \
  DOTFILES_REPO_URL="file://$source_repo" \
  DOTFILES_BOOTSTRAP_OS=omarchy \
  DOTFILES_BRANCH="$current_branch" \
  DOTFILES_STOW_CONFLICTS=backup \
    bash "$repo_dir/scripts/bootstrap.sh" </dev/null >"$success_output" 2>&1; then
  sed 's/^/  /' "$success_output"
  fail 'bootstrap fixture pacman-success failed'
fi
if [[ "${DOTFILES_FIXTURE_VERBOSE:-0}" == "1" ]]; then
  sed 's/^/  /' "$success_output"
fi
grep -Fq 'pacman prerequisite install returned: 0' "$success_output" || fail 'missing pacman success checkpoint'
grep -Fq 'Pacman sync databases are missing; syncing before installing prerequisites' "$success_output" || fail 'missing pacman success sync database checkpoint'
grep -Fq 'bootstrap prerequisites present after pacman' "$success_output" || fail 'missing pacman success verification checkpoint'
[[ -d "$tmp_dir/success-home/dotfiles/.git" ]] || fail 'dotfiles repo was not cloned after pacman success'

printf '==> bootstrap first-run fixture pass detached-update-recovery\n'
cp "$repo_dir/scripts/dotfiles" "$tmp_dir/success-home/dotfiles/scripts/dotfiles"
printf '\n# fixture detached update recovery\n' >>"$tmp_dir/success-home/dotfiles/scripts/dotfiles"
git -C "$tmp_dir/success-home/dotfiles" add scripts/dotfiles
git -C "$tmp_dir/success-home/dotfiles" \
  -c core.hooksPath=/dev/null \
  -c user.name='Dotfiles Test' \
  -c user.email='dotfiles-test@example.invalid' \
  commit -m 'test detached update recovery' >/dev/null
git -C "$tmp_dir/success-home/dotfiles" checkout --detach >/dev/null 2>&1
detached_output="$tmp_dir/detached-update.out"
if ! PATH="$tmp_dir/bin:$PATH" \
  PACMAN_MOCK_STATE="$tmp_dir/pacman-success-state" \
  PACMAN_MOCK_SYNC_DIR="$tmp_dir/pacman-success-sync" \
  HOME="$tmp_dir/success-home" \
  DOTFILES_DIR="$tmp_dir/success-home/dotfiles" \
  DOTFILES_PACMAN_SYNC_DIR="$tmp_dir/pacman-success-sync" \
  DOTFILES_ASSUME_YES=1 \
  DOTFILES_STOW_CONFLICTS=backup \
    "$tmp_dir/success-home/dotfiles/scripts/dotfiles" update >"$detached_output" 2>&1; then
  sed 's/^/  /' "$detached_output"
  fail 'detached update recovery failed'
fi
if [[ "${DOTFILES_FIXTURE_VERBOSE:-0}" == "1" ]]; then
  sed 's/^/  /' "$detached_output"
fi
grep -Fq 'repo is in detached HEAD; switching to' "$detached_output" || fail 'missing detached HEAD recovery warning'
[[ "$(git -C "$tmp_dir/success-home/dotfiles" branch --show-current)" == "$current_branch" ]] || fail 'repo did not return to the expected branch after detached update'

printf 'ok bootstrap first-run tests\n'
