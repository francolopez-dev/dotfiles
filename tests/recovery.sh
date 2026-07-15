#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/dotfiles-recovery-test.$$"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  printf 'fail: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP/bin" "$TMP/home/.ssh" "$TMP/config" "$TMP/state" "$TMP/out" "$TMP/home/.config/age" "$TMP/home/.local/share/atuin"

cat >"$TMP/bin/age" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-d" ]]; then
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) shift 2 ;;
      *) cat "$1"; exit 0 ;;
    esac
  done
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r) shift 2 ;;
      *) shift ;;
    esac
  done
  cat
fi
EOF
chmod +x "$TMP/bin/age"

cat >"$TMP/bin/msmtp" <<'EOF'
#!/usr/bin/env bash
cat >"$DOTFILES_RECOVERY_TEST_MAIL"
EOF
chmod +x "$TMP/bin/msmtp"

cat >"$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -I*) printf 'date: invalid argument %q for -I\n' "${1#-I}" >&2; exit 1 ;;
esac
if [[ -x /usr/bin/date ]]; then
  exec /usr/bin/date "$@"
fi
exec /bin/date "$@"
EOF
chmod +x "$TMP/bin/date"

cat >"$TMP/bin/base64" <<'EOF'
#!/usr/bin/env bash
if [[ $# -gt 0 ]]; then
  printf 'base64: invalid argument %s\n' "$1" >&2
  exit 1
fi
exec /usr/bin/base64
EOF
chmod +x "$TMP/bin/base64"

cat >"$TMP/config/recovery.local" <<EOF
RECOVERY_EMAIL_TO='restore@example.com'
RECOVERY_EMAIL_FROM='sender@gmail.com'
RECOVERY_SMTP_HOST=smtp.gmail.com
RECOVERY_SMTP_PORT=587
RECOVERY_SMTP_USER='sender@gmail.com'
RECOVERY_SMTP_PASSWORD='app-password'
RECOVERY_AGE_RECIPIENT='age1testrecipient'
RECOVERY_AGE_IDENTITY='$TMP/home/.config/age/recovery.txt'
RECOVERY_OUTPUT_DIR='$TMP/out'
RECOVERY_SEND_INTERVAL_DAYS='30'
EOF
chmod 600 "$TMP/config/recovery.local"

printf 'AGE-SECRET-KEY-test\n' >"$TMP/home/.config/age/recovery.txt"
printf 'private key\n' >"$TMP/home/.ssh/id_ed25519"
printf 'public key\n' >"$TMP/home/.ssh/id_ed25519.pub"
printf 'atuin-key\n' >"$TMP/home/.local/share/atuin/key"
printf 'atuin-session\n' >"$TMP/home/.local/share/atuin/session"
printf 'atuin-db\n' >"$TMP/home/.local/share/atuin/history.db"
chmod 600 "$TMP/home/.ssh/id_ed25519"

PATH="$TMP/bin:$PATH" \
HOME="$TMP/home" \
DOTFILES_OS=unknown \
DOTFILES_RECOVERY_CONFIG="$TMP/config/recovery.local" \
DOTFILES_RECOVERY_STATE_DIR="$TMP/state" \
DOTFILES_RECOVERY_TEST_MAIL="$TMP/mail.eml" \
"$ROOT/scripts/dotfiles" recovery send --no-prompt >/tmp/dotfiles-recovery-test.out

pack="$(sed -n '1p' "$TMP/state/last-pack")"
sent="$(sed -n '1p' "$TMP/state/last-sent")"
[[ -f "$pack" ]] || fail "pack was not created"
[[ "$pack" == "$sent" ]] || fail "last sent did not match last pack"
[[ -f "$TMP/mail.eml" ]] || fail "email was not captured"
grep -q 'Subject: recovery pack from' "$TMP/mail.eml" || fail "email subject missing"

PATH="$TMP/bin:$PATH" \
HOME="$TMP/home" \
DOTFILES_RECOVERY_CONFIG="$TMP/config/recovery.local" \
DOTFILES_RECOVERY_STATE_DIR="$TMP/state" \
"$ROOT/scripts/dotfiles" recovery verify "$pack" >/tmp/dotfiles-recovery-verify.out

grep -q 'ssh/id_ed25519' /tmp/dotfiles-recovery-verify.out || fail "ssh key missing from verified pack"
grep -q 'service-credentials/atuin/key' /tmp/dotfiles-recovery-verify.out || fail "atuin key missing from verified pack"
grep -q 'service-credentials/atuin/session' /tmp/dotfiles-recovery-verify.out || fail "atuin session missing from verified pack"
grep -q 'service-credentials/atuin/history.db' /tmp/dotfiles-recovery-verify.out || fail "atuin db missing from verified pack"

printf 'ok recovery tests\n'
