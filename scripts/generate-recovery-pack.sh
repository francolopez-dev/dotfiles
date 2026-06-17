#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

CONFIG_FILE="$REPO_DIR/config/recovery-pack.conf"
OUTPUT_DIR="$PWD"
PROFILE_NAME="${DOTFILES_PROFILE:-unknown}"
DRY_RUN=0
VERIFY_ARTIFACT=""
COPY_TO_NAS=0
NAS_TARGET_DIR=""
RESTIC_BACKUP=0
EMAIL_REPORT=0
HETZNER_COPY=0

TMP_ROOT=""
ARCHIVE_PATH=""
MANIFEST_SIDECAR=""
CHECKSUM_SIDECAR=""
DECRYPTED_ARCHIVE=""
HAVE_FAILURES=0
HAVE_WARNINGS=0
STATUS_NAS="skipped"
STATUS_RESTIC="skipped"
STATUS_HETZNER="skipped"
WARNINGS_LOG=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/generate-recovery-pack.sh [--config FILE] [--output-dir DIR] [--profile NAME] [--copy-to-nas] [--restic] [--email] [--hetzner]
  scripts/generate-recovery-pack.sh --dry-run [--config FILE] [--profile NAME] [--copy-to-nas] [--restic] [--email] [--hetzner]
  scripts/generate-recovery-pack.sh --verify ARTIFACT.age [--config FILE]

Options:
  --dry-run        Validate config and show planned archive contents. Creates no archive.
  --verify FILE    Decrypt and validate an existing recovery-pack .age artifact.
  --config FILE    Load recovery pack config. Default: config/recovery-pack.conf.
  --output-dir DIR Write encrypted artifact here. Default: current directory.
  --copy-to-nas    Copy encrypted artifact and safe sidecars to NAS target.
  --nas-dir DIR    Override NAS target. Default: RECOVERY_PACK_NAS_PATH from config.
  --restic         Back up encrypted artifact and sidecars to Restic repository.
  --email          Send email report after generation.
  --hetzner        Copy encrypted artifact and sidecars to Hetzner Storage Box.
  --profile NAME   Record profile name in metadata. Default: DOTFILES_PROFILE or unknown.
  --help           Show this help.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --verify)
      VERIFY_ARTIFACT="${2:-}"
      [ -n "$VERIFY_ARTIFACT" ] || die "--verify requires an artifact path"
      shift 2
      ;;
    --verify=*) VERIFY_ARTIFACT="${1#*=}"; shift ;;
    --config)
      CONFIG_FILE="${2:-}"
      [ -n "$CONFIG_FILE" ] || die "--config requires a file"
      shift 2
      ;;
    --config=*) CONFIG_FILE="${1#*=}"; shift ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      [ -n "$OUTPUT_DIR" ] || die "--output-dir requires a directory"
      shift 2
      ;;
    --output-dir=*) OUTPUT_DIR="${1#*=}"; shift ;;
    --copy-to-nas) COPY_TO_NAS=1; shift ;;
    --restic) RESTIC_BACKUP=1; shift ;;
    --email) EMAIL_REPORT=1; shift ;;
    --hetzner) HETZNER_COPY=1; shift ;;
    --nas-dir)
      NAS_TARGET_DIR="${2:-}"
      [ -n "$NAS_TARGET_DIR" ] || die "--nas-dir requires a directory"
      shift 2
      ;;
    --nas-dir=*) NAS_TARGET_DIR="${1#*=}"; shift ;;
    --profile)
      PROFILE_NAME="${2:-}"
      [ -n "$PROFILE_NAME" ] || die "--profile requires a name"
      shift 2
      ;;
    --profile=*) PROFILE_NAME="${1#*=}"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "generate-recovery-pack: unknown arg: $1" ;;
  esac
done

cleanup() {
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT INT TERM

tmp_parent() {
  if [ -n "${RECOVERY_PACK_TMPDIR:-}" ]; then
    printf "%s\n" "$RECOVERY_PACK_TMPDIR"
  elif [ -d /dev/shm ] && [ -w /dev/shm ]; then
    printf "%s\n" "/dev/shm"
  else
    printf "%s\n" "${TMPDIR:-/tmp}"
  fi
}

make_tmp_root() {
  TMP_ROOT="$(mktemp -d "$(tmp_parent)/recovery-pack.XXXXXX")"
}

warn_count() {
  HAVE_WARNINGS=1
  WARNINGS_LOG="${WARNINGS_LOG}${WARNINGS_LOG:+$'\n'}$*"
  warn "$*"
}

fail_count() {
  HAVE_FAILURES=1
  err "$*"
}

load_config() {
  [ -f "$CONFIG_FILE" ] || die "Missing config: $CONFIG_FILE"
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"

  ensure_array AGE_RECIPIENTS
  ensure_array AGE_BOOTSTRAP_IDENTITIES
  ensure_array AGE_IDENTITIES
  ensure_array SSH_PATHS
  ensure_array WIREGUARD_PATHS
  ensure_array VPN_PATHS
  ensure_array CERTIFICATE_PATHS
  ensure_array INFRA_EXPORT_PATHS
  ensure_array OPTIONAL_AGE_IDENTITIES
  ensure_array OPTIONAL_SSH_PATHS
  ensure_array OPTIONAL_WIREGUARD_PATHS
  ensure_array OPTIONAL_VPN_PATHS
  ensure_array OPTIONAL_CERTIFICATE_PATHS
  ensure_array OPTIONAL_INFRA_EXPORT_PATHS
  NAS_TARGET_DIR="${NAS_TARGET_DIR:-${RECOVERY_PACK_NAS_PATH:-/storage/backups/recovery-pack/}}"

  RECOVERY_PACK_RESTIC_ENABLED="${RECOVERY_PACK_RESTIC_ENABLED:-0}"
  RECOVERY_PACK_RESTIC_REPOSITORY="${RECOVERY_PACK_RESTIC_REPOSITORY:-}"
  RECOVERY_PACK_RESTIC_PASSWORD_FILE="${RECOVERY_PACK_RESTIC_PASSWORD_FILE:-}"
  RECOVERY_PACK_RESTIC_TAG="${RECOVERY_PACK_RESTIC_TAG:-recovery-pack}"

  if [ "$RESTIC_BACKUP" = "0" ] && [ "$RECOVERY_PACK_RESTIC_ENABLED" = "1" ]; then
    RESTIC_BACKUP=1
  fi

  RECOVERY_PACK_EMAIL_ENABLED="${RECOVERY_PACK_EMAIL_ENABLED:-0}"
  RECOVERY_PACK_EMAIL_TO="${RECOVERY_PACK_EMAIL_TO:-}"
  RECOVERY_PACK_EMAIL_FROM="${RECOVERY_PACK_EMAIL_FROM:-}"
  RECOVERY_PACK_EMAIL_ATTACH="${RECOVERY_PACK_EMAIL_ATTACH:-0}"
  if [ "$EMAIL_REPORT" = "0" ] && [ "$RECOVERY_PACK_EMAIL_ENABLED" = "1" ]; then
    EMAIL_REPORT=1
  fi

  RECOVERY_PACK_HETZNER_ENABLED="${RECOVERY_PACK_HETZNER_ENABLED:-0}"
  RECOVERY_PACK_HETZNER_TARGET="${RECOVERY_PACK_HETZNER_TARGET:-}"
  RECOVERY_PACK_HETZNER_PORT="${RECOVERY_PACK_HETZNER_PORT:-23}"
  if [ "$HETZNER_COPY" = "0" ] && [ "$RECOVERY_PACK_HETZNER_ENABLED" = "1" ]; then
    HETZNER_COPY=1
  fi
}

ensure_array() {
  local name="$1"
  if ! declare -p "$name" >/dev/null 2>&1; then
    eval "$name=()"
    return 0
  fi
  case "$(declare -p "$name")" in
    declare\ -a*) return 0 ;;
    *) die "$name must be a Bash array" ;;
  esac
}

array_len() {
  local name="$1"
  eval 'printf "%s\n" "${#'"$name"'[@]}"'
}

array_items_nul() {
  local name="$1"
  eval 'printf "%s\0" "${'"$name"'[@]}"'
}

entry_path() {
  local entry="$1"
  printf "%s\n" "${entry%%|*}"
}

entry_classification() {
  local entry="$1" default="$2" rest classification
  if [ "$entry" = "${entry%%|*}" ]; then
    printf "%s\n" "$default"
    return 0
  fi
  rest="${entry#*|}"
  classification="${rest%%|*}"
  [ -n "$classification" ] && printf "%s\n" "$classification" || printf "%s\n" "$default"
}

entry_reason() {
  local entry="$1" default="$2" rest
  if [ "$entry" = "${entry%%|*}" ]; then
    printf "%s\n" "$default"
    return 0
  fi
  rest="${entry#*|}"
  if [ "$rest" = "${rest%%|*}" ]; then
    printf "%s\n" "$default"
    return 0
  fi
  printf "%s\n" "${rest#*|}"
}

sha256_cmd() {
  if need_cmd sha256sum; then
    printf "%s\n" "sha256sum"
  elif need_cmd shasum; then
    printf "%s\n" "shasum -a 256"
  else
    return 1
  fi
}

validate_common() {
  need_cmd age || fail_count "Missing required command: age"
  need_cmd tar || fail_count "Missing required command: tar"
  need_cmd cp || fail_count "Missing required command: cp"
  sha256_cmd >/dev/null || fail_count "Missing required command: sha256sum or shasum"
  [ "$(array_len AGE_RECIPIENTS)" -gt 0 ] || fail_count "No Age recipients configured in AGE_RECIPIENTS"

  if [ "$DRY_RUN" = "0" ] || [ -n "$VERIFY_ARTIFACT" ]; then
    [ "$(array_len AGE_BOOTSTRAP_IDENTITIES)" -gt 0 ] || fail_count "No Age bootstrap identities configured in AGE_BOOTSTRAP_IDENTITIES"
  fi
}

validate_nas_target() {
  [ "$COPY_TO_NAS" = "1" ] || return 0
  [ -n "$NAS_TARGET_DIR" ] || fail_count "NAS target is empty"
  if [ ! -d "$NAS_TARGET_DIR" ]; then
    fail_count "NAS target does not exist or is not a directory: $NAS_TARGET_DIR"
    return 0
  fi
  [ -w "$NAS_TARGET_DIR" ] || fail_count "NAS target is not writable: $NAS_TARGET_DIR"
}

validate_restic() {
  [ "$RESTIC_BACKUP" = "1" ] || return 0
  need_cmd restic || fail_count "Missing required command: restic"
  local repo="${RECOVERY_PACK_RESTIC_REPOSITORY:-${RESTIC_REPOSITORY:-}}"
  [ -n "$repo" ] || fail_count "No Restic repository configured (RECOVERY_PACK_RESTIC_REPOSITORY or RESTIC_REPOSITORY)"
  local pw_file="${RECOVERY_PACK_RESTIC_PASSWORD_FILE:-${RESTIC_PASSWORD_FILE:-}}"
  local pw="${RESTIC_PASSWORD:-}"
  if [ -z "$pw_file" ] && [ -z "$pw" ]; then
    fail_count "No Restic password configured (RECOVERY_PACK_RESTIC_PASSWORD_FILE, RESTIC_PASSWORD_FILE, or RESTIC_PASSWORD)"
  fi
  if [ -n "$pw_file" ] && [ ! -f "$pw_file" ]; then
    fail_count "Restic password file does not exist: $pw_file"
  fi
}

validate_email() {
  [ "$EMAIL_REPORT" = "1" ] || return 0
  [ -n "$RECOVERY_PACK_EMAIL_TO" ] || fail_count "Email enabled but RECOVERY_PACK_EMAIL_TO is empty"
  if ! need_cmd mail && ! need_cmd sendmail && ! need_cmd msmtp; then
    fail_count "Email enabled but no mail command found (mail, sendmail, or msmtp)"
  fi
}

validate_hetzner() {
  [ "$HETZNER_COPY" = "1" ] || return 0
  [ -n "$RECOVERY_PACK_HETZNER_TARGET" ] || fail_count "Hetzner enabled but RECOVERY_PACK_HETZNER_TARGET is empty"
  need_cmd scp || fail_count "Hetzner enabled but scp is not available"
}

validate_paths_for_array() {
  local array_name="$1" label="$2" required="$3" entry path
  while IFS= read -r -d '' entry; do
    [ -n "$entry" ] || continue
    path="$(entry_path "$entry")"
    if [ -z "$path" ]; then
      warn_count "$label has an empty entry"
    elif [ ! -e "$path" ]; then
      if [ "$required" = "1" ]; then
        fail_count "$label required path missing: $path"
      else
        warn_count "$label optional path missing: $path"
      fi
    fi
  done < <(array_items_nul "$array_name")
}

validate_config() {
  validate_common
  validate_paths_for_array AGE_BOOTSTRAP_IDENTITIES "age-bootstrap" 1
  validate_paths_for_array AGE_IDENTITIES "age" 1
  validate_paths_for_array SSH_PATHS "ssh" 1
  validate_paths_for_array WIREGUARD_PATHS "wireguard" 1
  validate_paths_for_array VPN_PATHS "vpn" 1
  validate_paths_for_array CERTIFICATE_PATHS "certificates" 1
  validate_paths_for_array INFRA_EXPORT_PATHS "infrastructure-exports" 1
  validate_paths_for_array OPTIONAL_AGE_IDENTITIES "age" 0
  validate_paths_for_array OPTIONAL_SSH_PATHS "ssh" 0
  validate_paths_for_array OPTIONAL_WIREGUARD_PATHS "wireguard" 0
  validate_paths_for_array OPTIONAL_VPN_PATHS "vpn" 0
  validate_paths_for_array OPTIONAL_CERTIFICATE_PATHS "certificates" 0
  validate_paths_for_array OPTIONAL_INFRA_EXPORT_PATHS "infrastructure-exports" 0
  validate_nas_target
  validate_restic
  validate_email
  validate_hetzner
}

print_recipients() {
  local recipient
  info "Age recipients:"
  while IFS= read -r -d '' recipient; do
    [ -n "$recipient" ] || continue
    printf "  - %s\n" "$recipient"
  done < <(array_items_nul AGE_RECIPIENTS)
}

print_archive_structure() {
  cat <<'STRUCTURE'
Archive structure:
  recovery-pack/
  |-- MANIFEST.txt
  |-- CHECKSUMS.sha256
  |-- metadata/
  |   |-- created-at.txt
  |   |-- hostname.txt
  |   |-- profile.txt
  |   `-- tool-versions.txt
  |-- ssh/
  |-- age/
  |-- vpn/
  |-- wireguard/
  |-- certificates/
  `-- infrastructure-exports/
STRUCTURE
}

print_planned_for_array() {
  local array_name="$1" category="$2" archive_dir="$3" required="$4" entry path classification reason status
  while IFS= read -r -d '' entry; do
    [ -n "$entry" ] || continue
    path="$(entry_path "$entry")"
    classification="$(entry_classification "$entry" "${category}-recovery-material")"
    reason="$(entry_reason "$entry" "Configured in $array_name")"
    if [ -e "$path" ]; then
      status="include"
    elif [ "$required" = "1" ]; then
      status="missing-required"
    else
      status="missing-optional"
    fi
    printf "  - [%s] %s -> recovery-pack/%s/%s | %s | %s\n" \
      "$status" "$path" "$archive_dir" "$(basename "$path")" "$classification" "$reason"
  done < <(array_items_nul "$array_name")
}

dry_run() {
  info "Dry-run only. No archive, encryption, or copy operation will run."
  info "Config: $CONFIG_FILE"
  if [ "$COPY_TO_NAS" = "1" ]; then
    info "NAS copy target: $NAS_TARGET_DIR"
    info "NAS copy plan: encrypted .age artifact plus .manifest.txt and .sha256 sidecars"
  fi
  if [ "$RESTIC_BACKUP" = "1" ]; then
    local restic_repo="${RECOVERY_PACK_RESTIC_REPOSITORY:-${RESTIC_REPOSITORY:-}}"
    info "Restic backup: enabled"
    info "Restic repository: $restic_repo"
    info "Restic tag: $RECOVERY_PACK_RESTIC_TAG"
    info "Restic backup plan: encrypted .age artifact plus .manifest.txt and .sha256 sidecars"
  fi
  if [ "$EMAIL_REPORT" = "1" ]; then
    info "Email report: enabled"
    info "Email recipient: $RECOVERY_PACK_EMAIL_TO"
    if [ "$RECOVERY_PACK_EMAIL_ATTACH" = "1" ]; then
      info "Email attachment: enabled (encrypted .age artifact)"
    else
      info "Email attachment: disabled (report only)"
    fi
  fi
  if [ "$HETZNER_COPY" = "1" ]; then
    info "Hetzner copy: enabled"
    info "Hetzner target: $RECOVERY_PACK_HETZNER_TARGET"
    info "Hetzner port: $RECOVERY_PACK_HETZNER_PORT"
  fi
  print_recipients
  print_archive_structure
  info "Planned inputs:"
  print_planned_for_array AGE_IDENTITIES "age" "age" 1
  print_planned_for_array OPTIONAL_AGE_IDENTITIES "age" "age" 0
  print_planned_for_array SSH_PATHS "ssh" "ssh" 1
  print_planned_for_array OPTIONAL_SSH_PATHS "ssh" "ssh" 0
  print_planned_for_array WIREGUARD_PATHS "wireguard" "wireguard" 1
  print_planned_for_array OPTIONAL_WIREGUARD_PATHS "wireguard" "wireguard" 0
  print_planned_for_array VPN_PATHS "vpn" "vpn" 1
  print_planned_for_array OPTIONAL_VPN_PATHS "vpn" "vpn" 0
  print_planned_for_array CERTIFICATE_PATHS "certificates" "certificates" 1
  print_planned_for_array OPTIONAL_CERTIFICATE_PATHS "certificates" "certificates" 0
  print_planned_for_array INFRA_EXPORT_PATHS "infrastructure-exports" "infrastructure-exports" 1
  print_planned_for_array OPTIONAL_INFRA_EXPORT_PATHS "infrastructure-exports" "infrastructure-exports" 0
}

init_pack_tree() {
  local pack_dir="$1" now host versions
  mkdir -p \
    "$pack_dir/metadata" \
    "$pack_dir/ssh" \
    "$pack_dir/age" \
    "$pack_dir/vpn" \
    "$pack_dir/wireguard" \
    "$pack_dir/certificates" \
    "$pack_dir/infrastructure-exports"

  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  host="$(hostname 2>/dev/null || printf "unknown")"
  versions="$(age --version 2>/dev/null || printf "age version unavailable")"

  printf "%s\n" "$now" > "$pack_dir/metadata/created-at.txt"
  printf "%s\n" "$host" > "$pack_dir/metadata/hostname.txt"
  printf "%s\n" "$PROFILE_NAME" > "$pack_dir/metadata/profile.txt"
  printf "%s\n" "$versions" > "$pack_dir/metadata/tool-versions.txt"

  {
    printf "category\tsource_path\tarchive_path\tclassification\treason\n"
  } > "$pack_dir/MANIFEST.txt"
}

copy_entry() {
  local pack_dir="$1" category="$2" archive_dir="$3" array_name="$4" entry="$5"
  local src classification reason dest archive_path

  src="$(entry_path "$entry")"
  [ -e "$src" ] || return 0
  classification="$(entry_classification "$entry" "${category}-recovery-material")"
  reason="$(entry_reason "$entry" "Configured in $array_name")"
  dest="$pack_dir/$archive_dir/$(basename "$src")"
  archive_path="recovery-pack/$archive_dir/$(basename "$src")"

  [ ! -e "$dest" ] || die "Archive path collision: $archive_path"

  if [ -d "$src" ]; then
    cp -pR "$src" "$dest"
  else
    cp -p "$src" "$dest"
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$category" "$src" "$archive_path" "$classification" "$reason" >> "$pack_dir/MANIFEST.txt"
}

copy_entries_for_array() {
  local pack_dir="$1" array_name="$2" category="$3" archive_dir="$4" entry
  while IFS= read -r -d '' entry; do
    [ -n "$entry" ] || continue
    copy_entry "$pack_dir" "$category" "$archive_dir" "$array_name" "$entry"
  done < <(array_items_nul "$array_name")
}

copy_configured_inputs() {
  local pack_dir="$1"
  copy_entries_for_array "$pack_dir" AGE_IDENTITIES "age" "age"
  copy_entries_for_array "$pack_dir" OPTIONAL_AGE_IDENTITIES "age" "age"
  copy_entries_for_array "$pack_dir" SSH_PATHS "ssh" "ssh"
  copy_entries_for_array "$pack_dir" OPTIONAL_SSH_PATHS "ssh" "ssh"
  copy_entries_for_array "$pack_dir" WIREGUARD_PATHS "wireguard" "wireguard"
  copy_entries_for_array "$pack_dir" OPTIONAL_WIREGUARD_PATHS "wireguard" "wireguard"
  copy_entries_for_array "$pack_dir" VPN_PATHS "vpn" "vpn"
  copy_entries_for_array "$pack_dir" OPTIONAL_VPN_PATHS "vpn" "vpn"
  copy_entries_for_array "$pack_dir" CERTIFICATE_PATHS "certificates" "certificates"
  copy_entries_for_array "$pack_dir" OPTIONAL_CERTIFICATE_PATHS "certificates" "certificates"
  copy_entries_for_array "$pack_dir" INFRA_EXPORT_PATHS "infrastructure-exports" "infrastructure-exports"
  copy_entries_for_array "$pack_dir" OPTIONAL_INFRA_EXPORT_PATHS "infrastructure-exports" "infrastructure-exports"
}

write_checksums() {
  local pack_dir="$1"
  (
    cd "$(dirname "$pack_dir")"
    if need_cmd sha256sum; then
      find recovery-pack -type f ! -name CHECKSUMS.sha256 -print0 |
        sort -z |
        xargs -0 sha256sum
    else
      find recovery-pack -type f ! -name CHECKSUMS.sha256 -print0 |
        sort -z |
        xargs -0 shasum -a 256
    fi
  ) > "$pack_dir/CHECKSUMS.sha256"
}

write_artifact_checksum() {
  local artifact="$1" sidecar="$2"
  (
    cd "$(dirname "$artifact")"
    if need_cmd sha256sum; then
      sha256sum "$(basename "$artifact")"
    else
      shasum -a 256 "$(basename "$artifact")"
    fi
  ) > "$sidecar"
}

create_archive() {
  local work_dir="$1" pack_dir="$2" timestamp archive_plain recipient_args=() recipient base
  timestamp="$(date -u +"%Y-%m-%d-%H%M%S")"
  archive_plain="$work_dir/recovery-pack-$timestamp.tar.gz"
  base="recovery-pack-$timestamp"
  ARCHIVE_PATH="$OUTPUT_DIR/$base.tar.gz.age"
  MANIFEST_SIDECAR="$OUTPUT_DIR/$base.manifest.txt"
  CHECKSUM_SIDECAR="$OUTPUT_DIR/$base.sha256"

  mkdir -p "$OUTPUT_DIR"
  (
    cd "$work_dir"
    tar -czf "$archive_plain" recovery-pack
  )

  while IFS= read -r -d '' recipient; do
    [ -n "$recipient" ] || continue
    recipient_args+=("-r" "$recipient")
  done < <(array_items_nul AGE_RECIPIENTS)

  age "${recipient_args[@]}" -o "$ARCHIVE_PATH" "$archive_plain"
  rm -f "$archive_plain"
  [ -s "$ARCHIVE_PATH" ] || die "Encrypted artifact was not created: $ARCHIVE_PATH"
  cp -p "$pack_dir/MANIFEST.txt" "$MANIFEST_SIDECAR"
  write_artifact_checksum "$ARCHIVE_PATH" "$CHECKSUM_SIDECAR"
  [ -s "$MANIFEST_SIDECAR" ] || die "Manifest sidecar was not created: $MANIFEST_SIDECAR"
  [ -s "$CHECKSUM_SIDECAR" ] || die "Checksum sidecar was not created: $CHECKSUM_SIDECAR"
}

copy_to_nas() {
  local src dest
  [ "$COPY_TO_NAS" = "1" ] || return 0
  for src in "$ARCHIVE_PATH" "$MANIFEST_SIDECAR" "$CHECKSUM_SIDECAR"; do
    [ -f "$src" ] || die "Refusing NAS copy; missing source file: $src"
    dest="$NAS_TARGET_DIR/$(basename "$src")"
    cp -p "$src" "$dest"
    [ -s "$dest" ] || die "NAS copy failed or produced empty file: $dest"
    ok "copied $(basename "$src") to $NAS_TARGET_DIR"
  done
  STATUS_NAS="ok"
}

backup_to_restic() {
  [ "$RESTIC_BACKUP" = "1" ] || return 0
  local restic_env=() repo pw_file
  repo="${RECOVERY_PACK_RESTIC_REPOSITORY:-${RESTIC_REPOSITORY:-}}"
  pw_file="${RECOVERY_PACK_RESTIC_PASSWORD_FILE:-${RESTIC_PASSWORD_FILE:-}}"
  [ -n "$repo" ] && restic_env+=("RESTIC_REPOSITORY=$repo")
  [ -n "$pw_file" ] && restic_env+=("RESTIC_PASSWORD_FILE=$pw_file")

  local staging_dir
  staging_dir="$TMP_ROOT/restic-staging"
  mkdir -p "$staging_dir"
  cp -p "$ARCHIVE_PATH" "$MANIFEST_SIDECAR" "$CHECKSUM_SIDECAR" "$staging_dir/"

  env "${restic_env[@]}" restic backup \
    --tag "$RECOVERY_PACK_RESTIC_TAG" \
    "$staging_dir"

  STATUS_RESTIC="ok"
  ok "restic backup completed (tag: $RECOVERY_PACK_RESTIC_TAG)"
}

copy_to_hetzner() {
  [ "$HETZNER_COPY" = "1" ] || return 0
  local src target="${RECOVERY_PACK_HETZNER_TARGET}" port="${RECOVERY_PACK_HETZNER_PORT}"
  for src in "$ARCHIVE_PATH" "$MANIFEST_SIDECAR" "$CHECKSUM_SIDECAR"; do
    [ -f "$src" ] || { warn_count "Hetzner copy skipped; missing source: $src"; STATUS_HETZNER="failed"; return 0; }
    if ! scp -P "$port" "$src" "$target" 2>/dev/null; then
      warn_count "Hetzner copy failed for $(basename "$src")"
      STATUS_HETZNER="failed"
      return 0
    fi
    ok "copied $(basename "$src") to Hetzner"
  done
  STATUS_HETZNER="ok"
}

generate_email_body() {
  local artifact_size checksum_line
  artifact_size="$(wc -c < "$ARCHIVE_PATH" | tr -d ' ')"
  checksum_line="$(cat "$CHECKSUM_SIDECAR")"

  cat <<REPORT
Recovery Pack Report
====================
Timestamp:     $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Hostname:      $(hostname 2>/dev/null || printf "unknown")
Profile:       $PROFILE_NAME
Artifact:      $(basename "$ARCHIVE_PATH")
Size:          ${artifact_size} bytes
Checksum:      ${checksum_line}
NAS status:    $STATUS_NAS
Restic status: $STATUS_RESTIC
Hetzner status: $STATUS_HETZNER
REPORT

  if [ -n "$WARNINGS_LOG" ]; then
    printf "\nWarnings:\n%s\n" "$WARNINGS_LOG"
  fi

  if [ "$RECOVERY_PACK_EMAIL_ATTACH" = "1" ]; then
    printf "\nEncrypted artifact attached.\n"
  else
    printf "\nNo attachment (report only).\n"
  fi
}

send_email_report() {
  [ "$EMAIL_REPORT" = "1" ] || return 0
  local subject body from_args=()
  subject="Recovery Pack Report - $(hostname 2>/dev/null || printf "unknown") - $(date -u +"%Y-%m-%d")"
  body="$(generate_email_body)"

  [ -n "$RECOVERY_PACK_EMAIL_FROM" ] && from_args=("-r" "$RECOVERY_PACK_EMAIL_FROM")

  if [ "$RECOVERY_PACK_EMAIL_ATTACH" = "1" ] && need_cmd msmtp; then
    {
      printf "To: %s\n" "$RECOVERY_PACK_EMAIL_TO"
      [ -n "$RECOVERY_PACK_EMAIL_FROM" ] && printf "From: %s\n" "$RECOVERY_PACK_EMAIL_FROM"
      printf "Subject: %s\n" "$subject"
      printf "MIME-Version: 1.0\n"
      printf 'Content-Type: multipart/mixed; boundary="RECOVERY_PACK_BOUNDARY"\n\n'
      printf -- "--RECOVERY_PACK_BOUNDARY\n"
      printf "Content-Type: text/plain; charset=utf-8\n\n"
      printf "%s\n\n" "$body"
      printf -- "--RECOVERY_PACK_BOUNDARY\n"
      printf "Content-Type: application/octet-stream; name=\"%s\"\n" "$(basename "$ARCHIVE_PATH")"
      printf "Content-Transfer-Encoding: base64\n"
      printf "Content-Disposition: attachment; filename=\"%s\"\n\n" "$(basename "$ARCHIVE_PATH")"
      base64 < "$ARCHIVE_PATH"
      printf "\n--RECOVERY_PACK_BOUNDARY--\n"
    } | msmtp "$RECOVERY_PACK_EMAIL_TO"
  elif [ "$RECOVERY_PACK_EMAIL_ATTACH" = "1" ] && need_cmd mail; then
    printf "%s\n" "$body" | mail "${from_args[@]}" -s "$subject" -A "$ARCHIVE_PATH" "$RECOVERY_PACK_EMAIL_TO"
  elif need_cmd mail; then
    printf "%s\n" "$body" | mail "${from_args[@]}" -s "$subject" "$RECOVERY_PACK_EMAIL_TO"
  elif need_cmd msmtp; then
    {
      printf "To: %s\n" "$RECOVERY_PACK_EMAIL_TO"
      [ -n "$RECOVERY_PACK_EMAIL_FROM" ] && printf "From: %s\n" "$RECOVERY_PACK_EMAIL_FROM"
      printf "Subject: %s\n\n" "$subject"
      printf "%s\n" "$body"
    } | msmtp "$RECOVERY_PACK_EMAIL_TO"
  elif need_cmd sendmail; then
    {
      printf "To: %s\n" "$RECOVERY_PACK_EMAIL_TO"
      [ -n "$RECOVERY_PACK_EMAIL_FROM" ] && printf "From: %s\n" "$RECOVERY_PACK_EMAIL_FROM"
      printf "Subject: %s\n\n" "$subject"
      printf "%s\n" "$body"
    } | sendmail "$RECOVERY_PACK_EMAIL_TO"
  else
    warn_count "No mail command available; email report skipped"
    return 0
  fi
  ok "email report sent to $RECOVERY_PACK_EMAIL_TO"
}

build_pack() {
  local work_dir pack_dir
  make_tmp_root
  work_dir="$TMP_ROOT/work"
  pack_dir="$work_dir/recovery-pack"
  mkdir -p "$work_dir"
  init_pack_tree "$pack_dir"
  copy_configured_inputs "$pack_dir"
  write_checksums "$pack_dir"
  create_archive "$work_dir" "$pack_dir"
  copy_to_nas
  backup_to_restic
  copy_to_hetzner
  send_email_report
  ok "created $ARCHIVE_PATH"
}

identity_args() {
  local identity identity_path args=()
  while IFS= read -r -d '' identity; do
    [ -n "$identity" ] || continue
    identity_path="$(entry_path "$identity")"
    args+=("-i" "$identity_path")
  done < <(array_items_nul AGE_BOOTSTRAP_IDENTITIES)
  printf "%s\0" "${args[@]}"
}

verify_structure() {
  local root="$1" missing=0 dir pack
  pack="$root/recovery-pack"
  [ -d "$pack" ] || { err "Missing recovery-pack root"; return 1; }
  [ -f "$pack/MANIFEST.txt" ] || { err "Missing MANIFEST.txt"; missing=1; }
  [ -f "$pack/CHECKSUMS.sha256" ] || { err "Missing CHECKSUMS.sha256"; missing=1; }
  for dir in metadata ssh age vpn wireguard certificates infrastructure-exports; do
    [ -d "$pack/$dir" ] || { err "Missing directory: recovery-pack/$dir"; missing=1; }
  done
  [ -f "$pack/metadata/created-at.txt" ] || { err "Missing metadata/created-at.txt"; missing=1; }
  [ -f "$pack/metadata/hostname.txt" ] || { err "Missing metadata/hostname.txt"; missing=1; }
  [ -f "$pack/metadata/profile.txt" ] || { err "Missing metadata/profile.txt"; missing=1; }
  [ -f "$pack/metadata/tool-versions.txt" ] || { err "Missing metadata/tool-versions.txt"; missing=1; }
  return "$missing"
}

verify_checksums() {
  local root="$1"
  (
    cd "$root"
    if need_cmd sha256sum; then
      sha256sum -c recovery-pack/CHECKSUMS.sha256 >/dev/null
    else
      shasum -a 256 -c recovery-pack/CHECKSUMS.sha256 >/dev/null
    fi
  )
}

verify_artifact() {
  local artifact="$1" verify_dir extract_dir identity_args_array=() arg
  [ -f "$artifact" ] || die "Artifact not found: $artifact"
  make_tmp_root
  verify_dir="$TMP_ROOT/verify"
  extract_dir="$verify_dir/extract"
  mkdir -p "$verify_dir" "$extract_dir"
  DECRYPTED_ARCHIVE="$verify_dir/recovery-pack.tar.gz"

  while IFS= read -r -d '' arg; do
    [ -n "$arg" ] || continue
    identity_args_array+=("$arg")
  done < <(identity_args)

  age -d "${identity_args_array[@]}" -o "$DECRYPTED_ARCHIVE" "$artifact"
  [ -s "$DECRYPTED_ARCHIVE" ] || die "Decrypted archive is empty"
  tar -xzf "$DECRYPTED_ARCHIVE" -C "$extract_dir"
  verify_structure "$extract_dir"
  verify_checksums "$extract_dir"
  ok "verified $artifact"
}

main() {
  load_config
  validate_config

  if [ "$HAVE_FAILURES" = "1" ]; then
    die "Recovery Pack validation failed"
  fi

  if [ "$DRY_RUN" = "1" ]; then
    dry_run
    [ "$HAVE_WARNINGS" = "0" ] || warn "Dry-run completed with warnings"
    return 0
  fi

  if [ -n "$VERIFY_ARTIFACT" ]; then
    verify_artifact "$VERIFY_ARTIFACT"
  else
    build_pack
  fi
}

main
