#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT="$REPO_DIR/scripts/generate-recovery-pack.sh"
FIXTURES="$TEST_DIR/fixtures"
WORK_DIR="$TEST_DIR/.tmp"
OUTPUT_DIR="$WORK_DIR/output"
NAS_DIR="$WORK_DIR/nas"
TMP_WORKSPACES="$WORK_DIR/tmp"
CONFIG_FILE="$WORK_DIR/recovery-pack.test.conf"
IDENTITY_FILE="$WORK_DIR/test-age-identity.txt"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  printf "FAIL %s\n" "$*" >&2
  exit 1
}

pass() {
  printf "PASS %s\n" "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

setup_fixture_config() {
  local recipient
  mkdir -p "$OUTPUT_DIR" "$NAS_DIR" "$TMP_WORKSPACES"
  age-keygen -o "$IDENTITY_FILE" >/dev/null 2>&1
  recipient="$(grep '^# public key:' "$IDENTITY_FILE" | awk '{print $4}')"
  [ -n "$recipient" ] || fail "could not read test Age recipient"

  cat > "$CONFIG_FILE" <<CONFIG
RECOVERY_PACK_NAS_PATH="$NAS_DIR"

AGE_RECIPIENTS=(
  "$recipient"
)

AGE_BOOTSTRAP_IDENTITIES=(
  "$IDENTITY_FILE|test-age-bootstrap|Dummy test identity outside the Recovery Pack"
)

AGE_IDENTITIES=(
  "$FIXTURES/age/restore-identity.txt|test-age-identity|Dummy Age restore identity"
)

SSH_PATHS=(
  "$FIXTURES/ssh/id_ed25519|test-ssh-key|Dummy SSH key"
)

WIREGUARD_PATHS=(
  "$FIXTURES/wireguard/wg0.conf|test-wireguard-config|Dummy WireGuard config"
)

VPN_PATHS=(
  "$FIXTURES/vpn/profile.ovpn|test-vpn-profile|Dummy VPN profile"
)

CERTIFICATE_PATHS=(
  "$FIXTURES/certificates/example.key|test-certificate-key|Dummy certificate key"
)

INFRA_EXPORT_PATHS=(
  "$FIXTURES/infrastructure-exports/cloudflare-zones.json|cloudflare-export|Dummy Cloudflare zone export"
  "$FIXTURES/infrastructure-exports/tailscale-acl.json|tailscale-acl|Dummy Tailscale ACL export without machine state"
  "$FIXTURES/infrastructure-exports/router-backup.conf|router-backup|Dummy router backup"
  "$FIXTURES/infrastructure-exports/firewall-backup.conf|firewall-backup|Dummy firewall backup"
  "$FIXTURES/infrastructure-exports/proxmox-cluster.conf|proxmox-config|Dummy Proxmox cluster config"
  "$FIXTURES/infrastructure-exports/vaultwarden-backup-metadata.json|vaultwarden-metadata|Dummy Vaultwarden metadata"
  "$FIXTURES/infrastructure-exports/restic-repositories.txt|restic-repository-info|Dummy Restic repository info"
)

OPTIONAL_AGE_IDENTITIES=(
)

OPTIONAL_SSH_PATHS=(
  "$FIXTURES/ssh/missing-optional-key|test-optional-ssh-key|Expected missing optional SSH key"
)

OPTIONAL_WIREGUARD_PATHS=(
)

OPTIONAL_VPN_PATHS=(
)

OPTIONAL_CERTIFICATE_PATHS=(
)

OPTIONAL_INFRA_EXPORT_PATHS=(
)
CONFIG
}

run_generator() {
  RECOVERY_PACK_TMPDIR="$TMP_WORKSPACES" "$SCRIPT" "$@"
}

assert_no_archives() {
  local count
  count="$(find "$OUTPUT_DIR" -type f -name 'recovery-pack-*.tar.gz.age' | wc -l | tr -d ' ')"
  [ "$count" = "0" ] || fail "dry-run created encrypted archives"
}

assert_no_nas_files() {
  local count
  count="$(find "$NAS_DIR" -type f | wc -l | tr -d ' ')"
  [ "$count" = "0" ] || fail "dry-run copied files to NAS target"
}

assert_one_archive() {
  local count
  count="$(find "$OUTPUT_DIR" -type f -name 'recovery-pack-*.tar.gz.age' | wc -l | tr -d ' ')"
  [ "$count" = "1" ] || fail "expected one encrypted archive, found $count"
}

assert_sidecars_for_archive() {
  local artifact="$1" base
  base="${artifact%.tar.gz.age}"
  [ -s "$base.manifest.txt" ] || fail "missing manifest sidecar for $artifact"
  [ -s "$base.sha256" ] || fail "missing checksum sidecar for $artifact"
  grep -q "$(basename "$artifact")" "$base.sha256" || fail "checksum sidecar does not reference artifact basename"
}

latest_archive() {
  find "$OUTPUT_DIR" -type f -name 'recovery-pack-*.tar.gz.age' | sort | tail -n 1
}

assert_tmp_clean() {
  if find "$TMP_WORKSPACES" -maxdepth 1 -type d -name 'recovery-pack.*' | grep -q .; then
    fail "temporary recovery-pack workspace was left behind"
  fi
}

test_dry_run() {
  run_generator --dry-run --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" > "$WORK_DIR/dry-run.out" 2> "$WORK_DIR/dry-run.err"
  grep -q "Dry-run only" "$WORK_DIR/dry-run.out" || fail "dry-run output missing dry-run marker"
  grep -q "missing-optional" "$WORK_DIR/dry-run.out" || fail "dry-run output missing optional path status"
  assert_no_archives
  assert_tmp_clean
  pass "dry-run"
}

test_nas_dry_run() {
  run_generator --dry-run --copy-to-nas --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" > "$WORK_DIR/nas-dry-run.out" 2> "$WORK_DIR/nas-dry-run.err"
  grep -q "NAS copy target" "$WORK_DIR/nas-dry-run.out" || fail "NAS dry-run output missing target"
  grep -q "NAS copy plan" "$WORK_DIR/nas-dry-run.out" || fail "NAS dry-run output missing copy plan"
  assert_no_archives
  assert_no_nas_files
  assert_tmp_clean
  pass "nas-dry-run"
}

test_nas_validation() {
  local missing_dir
  missing_dir="$WORK_DIR/missing-nas"
  if run_generator --dry-run --copy-to-nas --nas-dir "$missing_dir" --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" > "$WORK_DIR/nas-validation.out" 2> "$WORK_DIR/nas-validation.err"; then
    fail "NAS validation unexpectedly passed for missing target"
  fi
  grep -q "NAS target does not exist" "$WORK_DIR/nas-validation.err" || fail "NAS validation error missing"
  assert_no_archives
  assert_no_nas_files
  assert_tmp_clean
  pass "nas-validation"
}

test_build() {
  local artifact
  run_generator --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" --profile test-profile > "$WORK_DIR/build.out" 2> "$WORK_DIR/build.err"
  assert_one_archive
  artifact="$(latest_archive)"
  assert_sidecars_for_archive "$artifact"
  assert_tmp_clean
  pass "build"
}

test_nas_copy() {
  local artifact copied_artifact base
  rm -f "$OUTPUT_DIR"/recovery-pack-* "$NAS_DIR"/recovery-pack-*
  run_generator --copy-to-nas --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" --profile test-profile > "$WORK_DIR/nas-copy.out" 2> "$WORK_DIR/nas-copy.err"
  assert_one_archive
  artifact="$(latest_archive)"
  base="$(basename "${artifact%.tar.gz.age}")"
  copied_artifact="$NAS_DIR/$(basename "$artifact")"
  [ -s "$copied_artifact" ] || fail "encrypted artifact was not copied to NAS target"
  [ -s "$NAS_DIR/$base.manifest.txt" ] || fail "manifest sidecar was not copied to NAS target"
  [ -s "$NAS_DIR/$base.sha256" ] || fail "checksum sidecar was not copied to NAS target"
  cmp -s "$artifact" "$copied_artifact" || fail "copied encrypted artifact differs from source"
  cmp -s "${artifact%.tar.gz.age}.manifest.txt" "$NAS_DIR/$base.manifest.txt" || fail "copied manifest sidecar differs from source"
  cmp -s "${artifact%.tar.gz.age}.sha256" "$NAS_DIR/$base.sha256" || fail "copied checksum sidecar differs from source"
  assert_tmp_clean
  pass "nas-copy"
}

test_verify() {
  local artifact
  artifact="$(latest_archive)"
  [ -n "$artifact" ] || fail "no artifact to verify"
  run_generator --verify "$artifact" --config "$CONFIG_FILE" > "$WORK_DIR/verify.out" 2> "$WORK_DIR/verify.err"
  grep -q "verified" "$WORK_DIR/verify.out" || fail "verify output missing success marker"
  assert_tmp_clean
  pass "verify"
}

test_cleanup() {
  assert_tmp_clean
  pass "cleanup"
}

main() {
  need_cmd age
  need_cmd age-keygen
  need_cmd tar
  rm -rf "$WORK_DIR"
  setup_fixture_config
  test_dry_run
  test_nas_dry_run
  test_nas_validation
  test_build
  test_verify
  test_nas_copy
  test_cleanup
}

main
