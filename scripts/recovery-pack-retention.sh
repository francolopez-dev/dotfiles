#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

CONFIG_FILE="$REPO_DIR/config/recovery-pack.conf"
KEEP_COUNT=5
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/recovery-pack-retention.sh [--keep N] [--config FILE] [--dry-run]

Removes old recovery pack artifacts from the NAS target directory,
keeping the N most recent sets (artifact + sidecars). Default: 5.

Options:
  --keep N       Number of artifact sets to keep. Default: 5.
  --config FILE  Load recovery pack config. Default: config/recovery-pack.conf.
  --dry-run      Show what would be removed without deleting.
  --help         Show this help.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --keep)
      KEEP_COUNT="${2:-}"
      [ -n "$KEEP_COUNT" ] || die "--keep requires a number"
      shift 2
      ;;
    --keep=*) KEEP_COUNT="${1#*=}"; shift ;;
    --config)
      CONFIG_FILE="${2:-}"
      [ -n "$CONFIG_FILE" ] || die "--config requires a file"
      shift 2
      ;;
    --config=*) CONFIG_FILE="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "recovery-pack-retention: unknown arg: $1" ;;
  esac
done

[ -f "$CONFIG_FILE" ] || die "Missing config: $CONFIG_FILE"
# shellcheck source=/dev/null
. "$CONFIG_FILE"

NAS_DIR="${RECOVERY_PACK_NAS_PATH:-/storage/backups/recovery-pack/}"
[ -d "$NAS_DIR" ] || die "NAS directory does not exist: $NAS_DIR"

artifacts=()
while IFS= read -r f; do
  [ -n "$f" ] && artifacts+=("$f")
done < <(find "$NAS_DIR" -maxdepth 1 -name 'recovery-pack-*.tar.gz.age' -type f | sort -r)

total="${#artifacts[@]}"
if [ "$total" -le "$KEEP_COUNT" ]; then
  info "Found $total artifact(s), keeping $KEEP_COUNT. Nothing to remove."
  exit 0
fi

remove_count=$((total - KEEP_COUNT))
info "Found $total artifact(s), keeping $KEEP_COUNT, removing $remove_count."

for ((i = KEEP_COUNT; i < total; i++)); do
  artifact="${artifacts[$i]}"
  base="${artifact%.tar.gz.age}"
  for f in "$artifact" "$base.manifest.txt" "$base.sha256"; do
    if [ -f "$f" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] would remove: $(basename "$f")"
      else
        rm -f "$f"
        ok "removed $(basename "$f")"
      fi
    fi
  done
done
