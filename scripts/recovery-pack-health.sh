#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

CONFIG_FILE="$REPO_DIR/config/recovery-pack.conf"
MAX_AGE_DAYS=14

usage() {
  cat <<'USAGE'
Usage:
  scripts/recovery-pack-health.sh [--config FILE] [--max-age DAYS]

Validates that the NAS target contains at least one recent recovery pack
artifact and that its checksum sidecar is consistent.

Options:
  --config FILE    Load recovery pack config. Default: config/recovery-pack.conf.
  --max-age DAYS   Maximum age in days for the most recent artifact. Default: 14.
  --help           Show this help.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      [ -n "$CONFIG_FILE" ] || die "--config requires a file"
      shift 2
      ;;
    --config=*) CONFIG_FILE="${1#*=}"; shift ;;
    --max-age)
      MAX_AGE_DAYS="${2:-}"
      [ -n "$MAX_AGE_DAYS" ] || die "--max-age requires a number"
      shift 2
      ;;
    --max-age=*) MAX_AGE_DAYS="${1#*=}"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "recovery-pack-health: unknown arg: $1" ;;
  esac
done

[ -f "$CONFIG_FILE" ] || die "Missing config: $CONFIG_FILE"
# shellcheck source=/dev/null
. "$CONFIG_FILE"

NAS_DIR="${RECOVERY_PACK_NAS_PATH:-/storage/backups/recovery-pack/}"
HAVE_FAILURES=0

fail_check() {
  HAVE_FAILURES=1
  err "$*"
}

if [ ! -d "$NAS_DIR" ]; then
  fail_check "NAS directory does not exist: $NAS_DIR"
  exit 1
fi

latest="$(find "$NAS_DIR" -maxdepth 1 -name 'recovery-pack-*.tar.gz.age' -type f | sort -r | head -n 1)"
if [ -z "$latest" ]; then
  fail_check "No recovery pack artifacts found in $NAS_DIR"
  exit 1
fi

ok "latest artifact: $(basename "$latest")"

base="${latest%.tar.gz.age}"
[ -f "$base.manifest.txt" ] || fail_check "Missing manifest sidecar: $(basename "$base").manifest.txt"
[ -f "$base.sha256" ] || fail_check "Missing checksum sidecar: $(basename "$base").sha256"

if [ -f "$base.sha256" ]; then
  (
    cd "$NAS_DIR"
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum -c "$(basename "$base").sha256" >/dev/null
    else
      shasum -a 256 -c "$(basename "$base").sha256" >/dev/null
    fi
  ) || fail_check "Checksum verification failed for $(basename "$latest")"
  [ "$HAVE_FAILURES" = "0" ] && ok "checksum verified"
fi

if command -v stat >/dev/null 2>&1; then
  if stat --version >/dev/null 2>&1; then
    file_epoch="$(stat -c %Y "$latest")"
  else
    file_epoch="$(stat -f %m "$latest")"
  fi
  now_epoch="$(date +%s)"
  age_days=$(( (now_epoch - file_epoch) / 86400 ))
  if [ "$age_days" -gt "$MAX_AGE_DAYS" ]; then
    fail_check "Latest artifact is ${age_days} days old (max: $MAX_AGE_DAYS)"
  else
    ok "artifact age: ${age_days} day(s) (max: $MAX_AGE_DAYS)"
  fi
fi

if [ "$HAVE_FAILURES" = "1" ]; then
  die "Health check failed"
fi
ok "health check passed"
