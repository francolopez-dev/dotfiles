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

TMP_ROOT=""
ARCHIVE_PATH=""
DECRYPTED_ARCHIVE=""
HAVE_FAILURES=0
HAVE_WARNINGS=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/generate-recovery-pack.sh [--config FILE] [--output-dir DIR] [--profile NAME]
  scripts/generate-recovery-pack.sh --dry-run [--config FILE] [--profile NAME]
  scripts/generate-recovery-pack.sh --verify ARTIFACT.age [--config FILE]

Options:
  --dry-run        Validate config and show planned archive contents. Creates no archive.
  --verify FILE    Decrypt and validate an existing recovery-pack .age artifact.
  --config FILE    Load recovery pack config. Default: config/recovery-pack.conf.
  --output-dir DIR Write encrypted artifact here. Default: current directory.
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
  sha256_cmd >/dev/null || fail_count "Missing required command: sha256sum or shasum"
  [ "$(array_len AGE_RECIPIENTS)" -gt 0 ] || fail_count "No Age recipients configured in AGE_RECIPIENTS"

  if [ "$DRY_RUN" = "0" ] || [ -n "$VERIFY_ARTIFACT" ]; then
    [ "$(array_len AGE_BOOTSTRAP_IDENTITIES)" -gt 0 ] || fail_count "No Age bootstrap identities configured in AGE_BOOTSTRAP_IDENTITIES"
  fi
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

create_archive() {
  local work_dir="$1" timestamp archive_plain recipient_args=() recipient
  timestamp="$(date -u +"%Y-%m-%d-%H%M%S")"
  archive_plain="$work_dir/recovery-pack-$timestamp.tar.gz"
  ARCHIVE_PATH="$OUTPUT_DIR/recovery-pack-$timestamp.tar.gz.age"

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
  create_archive "$work_dir"
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
