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

mkdir -p "$tmp_dir/bin" "$tmp_dir/home" "$tmp_dir/pacman-state"

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
  -S)
    shift
    for arg in "$@"; do
      [[ "$arg" == --* ]] && continue
      touch "$state_dir/$arg"
    done
    if [[ ! -e "$state_dir/failed-once" ]]; then
      touch "$state_dir/failed-once"
      printf 'bash: line 143: symlink: No such file or directory\n' >&2
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

chmod +x "$tmp_dir/bin/sudo" "$tmp_dir/bin/pacman" "$tmp_dir/bin/stow" "$tmp_dir/bin/git"

for run in 1 2; do
  printf '==> bootstrap first-run fixture pass %s\n' "$run"
  PATH="$tmp_dir/bin:$PATH" \
  PACMAN_MOCK_STATE="$tmp_dir/pacman-state" \
  HOME="$tmp_dir/home" \
  DOTFILES_DIR="$tmp_dir/home/dotfiles" \
  DOTFILES_REPO_URL="file://$repo_dir" \
  DOTFILES_BOOTSTRAP_OS=omarchy \
  DOTFILES_BRANCH="$current_branch" \
  DOTFILES_STOW_CONFLICTS=backup \
    bash "$repo_dir/scripts/bootstrap.sh"

  [[ -d "$tmp_dir/home/dotfiles/.git" ]] || fail 'dotfiles repo was not cloned'
  [[ -L "$tmp_dir/home/.local/bin/dotfiles" ]] || fail 'dotfiles CLI was not linked'
  [[ -r "$tmp_dir/home/.oh-my-zsh/oh-my-zsh.sh" ]] || fail 'Oh My Zsh was not installed'
done

printf 'ok bootstrap first-run tests\n'
