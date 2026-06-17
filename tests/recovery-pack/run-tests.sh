#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT="$REPO_DIR/scripts/generate-recovery-pack.sh"
FIXTURES="$TEST_DIR/fixtures"
WORK_DIR="$TEST_DIR/.tmp"
OUTPUT_DIR="$WORK_DIR/output"
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
  mkdir -p "$OUTPUT_DIR" "$TMP_WORKSPACES"
  age-keygen -o "$IDENTITY_FILE" >/dev/null 2>&1
  recipient="$(grep '^# public key:' "$IDENTITY_FILE" | awk '{print $4}')"
  [ -n "$recipient" ] || fail "could not read test Age recipient"

  cat > "$CONFIG_FILE" <<CONFIG
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

assert_one_archive() {
  local count
  count="$(find "$OUTPUT_DIR" -type f -name 'recovery-pack-*.tar.gz.age' | wc -l | tr -d ' ')"
  [ "$count" = "1" ] || fail "expected one encrypted archive, found $count"
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

test_build() {
  run_generator --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" --profile test-profile > "$WORK_DIR/build.out" 2> "$WORK_DIR/build.err"
  assert_one_archive
  assert_tmp_clean
  pass "build"
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
  test_build
  test_verify
  test_cleanup
}

main
