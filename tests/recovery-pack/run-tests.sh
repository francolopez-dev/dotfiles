#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT="$REPO_DIR/scripts/generate-recovery-pack.sh"
RETENTION_SCRIPT="$REPO_DIR/scripts/recovery-pack-retention.sh"
HEALTH_SCRIPT="$REPO_DIR/scripts/recovery-pack-health.sh"
FIXTURES="$TEST_DIR/fixtures"
WORK_DIR="$TEST_DIR/.tmp"
OUTPUT_DIR="$WORK_DIR/output"
NAS_DIR="$WORK_DIR/nas"
TMP_WORKSPACES="$WORK_DIR/tmp"
RESTIC_REPO_DIR="$WORK_DIR/restic-repo"
RESTIC_PW_FILE="$WORK_DIR/restic-password.txt"
CONFIG_FILE="$WORK_DIR/recovery-pack.test.conf"
RESTIC_CONFIG_FILE="$WORK_DIR/recovery-pack.restic.test.conf"
EMAIL_CONFIG_FILE="$WORK_DIR/recovery-pack.email.test.conf"
HETZNER_CONFIG_FILE="$WORK_DIR/recovery-pack.hetzner.test.conf"
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

  printf "test-restic-password\n" > "$RESTIC_PW_FILE"
  mkdir -p "$RESTIC_REPO_DIR"

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

  cat > "$RESTIC_CONFIG_FILE" <<RCONFIG
RECOVERY_PACK_NAS_PATH="$NAS_DIR"
RECOVERY_PACK_RESTIC_ENABLED=1
RECOVERY_PACK_RESTIC_REPOSITORY="$RESTIC_REPO_DIR"
RECOVERY_PACK_RESTIC_PASSWORD_FILE="$RESTIC_PW_FILE"
RECOVERY_PACK_RESTIC_TAG="recovery-pack-test"

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

OPTIONAL_AGE_IDENTITIES=()
OPTIONAL_SSH_PATHS=()
OPTIONAL_WIREGUARD_PATHS=()
OPTIONAL_VPN_PATHS=()
OPTIONAL_CERTIFICATE_PATHS=()
OPTIONAL_INFRA_EXPORT_PATHS=()
RCONFIG

  cat > "$WORK_DIR/mail" <<'MOCKMAIL'
#!/usr/bin/env bash
cat > /dev/null
MOCKMAIL
  chmod +x "$WORK_DIR/mail"

  cat > "$EMAIL_CONFIG_FILE" <<ECONFIG
RECOVERY_PACK_NAS_PATH="$NAS_DIR"
RECOVERY_PACK_EMAIL_ENABLED=1
RECOVERY_PACK_EMAIL_TO="test@example.com"
RECOVERY_PACK_EMAIL_FROM="recovery@example.com"
RECOVERY_PACK_EMAIL_ATTACH=0

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

OPTIONAL_AGE_IDENTITIES=()
OPTIONAL_SSH_PATHS=()
OPTIONAL_WIREGUARD_PATHS=()
OPTIONAL_VPN_PATHS=()
OPTIONAL_CERTIFICATE_PATHS=()
OPTIONAL_INFRA_EXPORT_PATHS=()
ECONFIG

  cat > "$HETZNER_CONFIG_FILE" <<HCONFIG
RECOVERY_PACK_NAS_PATH="$NAS_DIR"
RECOVERY_PACK_HETZNER_ENABLED=1
RECOVERY_PACK_HETZNER_TARGET=""
RECOVERY_PACK_HETZNER_PORT=23

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

WIREGUARD_PATHS=()
VPN_PATHS=()
CERTIFICATE_PATHS=()
INFRA_EXPORT_PATHS=()
OPTIONAL_AGE_IDENTITIES=()
OPTIONAL_SSH_PATHS=()
OPTIONAL_WIREGUARD_PATHS=()
OPTIONAL_VPN_PATHS=()
OPTIONAL_CERTIFICATE_PATHS=()
OPTIONAL_INFRA_EXPORT_PATHS=()
HCONFIG
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

test_restic_dry_run() {
  rm -f "$OUTPUT_DIR"/recovery-pack-*
  run_generator --dry-run --restic --config "$RESTIC_CONFIG_FILE" --output-dir "$OUTPUT_DIR" > "$WORK_DIR/restic-dry-run.out" 2> "$WORK_DIR/restic-dry-run.err"
  grep -q "Restic backup: enabled" "$WORK_DIR/restic-dry-run.out" || fail "restic dry-run missing enabled marker"
  grep -q "Restic repository:" "$WORK_DIR/restic-dry-run.out" || fail "restic dry-run missing repository"
  grep -q "Restic tag:" "$WORK_DIR/restic-dry-run.out" || fail "restic dry-run missing tag"
  assert_no_archives
  assert_tmp_clean
  pass "restic-dry-run"
}

test_restic_backup() {
  RESTIC_REPOSITORY="$RESTIC_REPO_DIR" RESTIC_PASSWORD_FILE="$RESTIC_PW_FILE" restic init > /dev/null 2>&1 || true
  rm -f "$OUTPUT_DIR"/recovery-pack-*
  run_generator --restic --config "$RESTIC_CONFIG_FILE" --output-dir "$OUTPUT_DIR" --profile test-profile > "$WORK_DIR/restic-backup.out" 2> "$WORK_DIR/restic-backup.err"
  assert_one_archive
  grep -q "restic backup completed" "$WORK_DIR/restic-backup.out" || fail "restic backup missing success marker"
  local snapshot_count
  snapshot_count="$(RESTIC_REPOSITORY="$RESTIC_REPO_DIR" RESTIC_PASSWORD_FILE="$RESTIC_PW_FILE" restic snapshots --tag recovery-pack-test --json 2>/dev/null | grep -c '"time"')"
  [ "$snapshot_count" -ge 1 ] || fail "no restic snapshots found with expected tag"
  assert_tmp_clean
  pass "restic-backup"
}

test_email_dry_run() {
  rm -f "$OUTPUT_DIR"/recovery-pack-*
  run_generator --dry-run --email --config "$EMAIL_CONFIG_FILE" --output-dir "$OUTPUT_DIR" > "$WORK_DIR/email-dry-run.out" 2> "$WORK_DIR/email-dry-run.err"
  grep -q "Email report: enabled" "$WORK_DIR/email-dry-run.out" || fail "email dry-run missing enabled marker"
  grep -q "Email recipient:" "$WORK_DIR/email-dry-run.out" || fail "email dry-run missing recipient"
  grep -q "Email attachment: disabled" "$WORK_DIR/email-dry-run.out" || fail "email dry-run missing attachment status"
  assert_no_archives
  assert_tmp_clean
  pass "email-dry-run"
}

test_email_build() {
  rm -f "$OUTPUT_DIR"/recovery-pack-*
  PATH="$WORK_DIR:$PATH" run_generator --email --config "$EMAIL_CONFIG_FILE" --output-dir "$OUTPUT_DIR" --profile test-profile > "$WORK_DIR/email-build.out" 2> "$WORK_DIR/email-build.err"
  assert_one_archive
  grep -q "email report sent" "$WORK_DIR/email-build.out" || fail "email build missing send confirmation"
  assert_tmp_clean
  pass "email-build"
}

test_hetzner_validation() {
  rm -f "$OUTPUT_DIR"/recovery-pack-*
  if run_generator --dry-run --hetzner --config "$HETZNER_CONFIG_FILE" --output-dir "$OUTPUT_DIR" > "$WORK_DIR/hetzner-validation.out" 2> "$WORK_DIR/hetzner-validation.err"; then
    fail "hetzner validation unexpectedly passed with empty target"
  fi
  grep -q "RECOVERY_PACK_HETZNER_TARGET is empty" "$WORK_DIR/hetzner-validation.err" || fail "hetzner validation error missing"
  assert_no_archives
  assert_tmp_clean
  pass "hetzner-validation"
}

test_restic_validation() {
  if run_generator --dry-run --restic --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" > "$WORK_DIR/restic-validation.out" 2> "$WORK_DIR/restic-validation.err"; then
    fail "restic validation unexpectedly passed without restic config"
  fi
  grep -q "No Restic repository configured" "$WORK_DIR/restic-validation.err" || fail "restic validation error missing"
  assert_no_archives
  assert_tmp_clean
  pass "restic-validation"
}

test_retention_dry_run() {
  rm -f "$NAS_DIR"/recovery-pack-*
  for _ in 1 2 3 4 5 6 7; do
    run_generator --copy-to-nas --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR" --profile test-profile > /dev/null 2>&1
    sleep 1
  done
  local count_before
  count_before="$(find "$NAS_DIR" -name 'recovery-pack-*.tar.gz.age' | wc -l | tr -d ' ')"
  [ "$count_before" = "7" ] || fail "expected 7 artifacts before retention, found $count_before"
  "$RETENTION_SCRIPT" --keep 3 --config "$CONFIG_FILE" --dry-run > "$WORK_DIR/retention-dry-run.out" 2> "$WORK_DIR/retention-dry-run.err"
  local count_after
  count_after="$(find "$NAS_DIR" -name 'recovery-pack-*.tar.gz.age' | wc -l | tr -d ' ')"
  [ "$count_after" = "7" ] || fail "dry-run retention removed files"
  grep -q "would remove" "$WORK_DIR/retention-dry-run.out" || fail "retention dry-run missing removal plan"
  pass "retention-dry-run"
}

test_retention_execute() {
  "$RETENTION_SCRIPT" --keep 3 --config "$CONFIG_FILE" > "$WORK_DIR/retention-execute.out" 2> "$WORK_DIR/retention-execute.err"
  local count_after
  count_after="$(find "$NAS_DIR" -name 'recovery-pack-*.tar.gz.age' | wc -l | tr -d ' ')"
  [ "$count_after" = "3" ] || fail "expected 3 artifacts after retention, found $count_after"
  local manifest_count sidecar_count
  manifest_count="$(find "$NAS_DIR" -name 'recovery-pack-*.manifest.txt' | wc -l | tr -d ' ')"
  sidecar_count="$(find "$NAS_DIR" -name 'recovery-pack-*.sha256' | wc -l | tr -d ' ')"
  [ "$manifest_count" = "3" ] || fail "expected 3 manifest sidecars, found $manifest_count"
  [ "$sidecar_count" = "3" ] || fail "expected 3 checksum sidecars, found $sidecar_count"
  pass "retention-execute"
}

test_health_pass() {
  "$HEALTH_SCRIPT" --config "$CONFIG_FILE" --max-age 1 > "$WORK_DIR/health-pass.out" 2> "$WORK_DIR/health-pass.err"
  grep -q "health check passed" "$WORK_DIR/health-pass.out" || fail "health check did not pass"
  pass "health-pass"
}

test_health_empty() {
  local empty_nas="$WORK_DIR/empty-nas"
  mkdir -p "$empty_nas"
  local tmp_conf="$WORK_DIR/health-empty.conf"
  printf 'RECOVERY_PACK_NAS_PATH="%s"\n' "$empty_nas" > "$tmp_conf"
  if "$HEALTH_SCRIPT" --config "$tmp_conf" > "$WORK_DIR/health-empty.out" 2> "$WORK_DIR/health-empty.err"; then
    fail "health check unexpectedly passed on empty NAS"
  fi
  grep -q "No recovery pack artifacts" "$WORK_DIR/health-empty.err" || fail "health empty error missing"
  pass "health-empty"
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
  test_email_dry_run
  test_email_build
  test_hetzner_validation
  if command -v restic >/dev/null 2>&1; then
    test_restic_dry_run
    test_restic_validation
    test_restic_backup
  else
    printf "SKIP restic tests (restic not installed)\n"
  fi
  test_retention_dry_run
  test_retention_execute
  test_health_pass
  test_health_empty
  test_cleanup
}

main
