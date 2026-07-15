#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/stow/global/tailscale-policy/.local/bin/dotfiles-tailscale-policy"
TMP="${TMPDIR:-/tmp}/dotfiles-tailscale-policy-test.$$"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/state"

cat >"$TMP/bin/tailscale" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  status)
    case "${TAILSCALE_POLICY_MOCK_TS_STATE:-up}" in
      up) exit 0 ;;
      down) printf 'Tailscale is stopped.\n' >&2; exit 1 ;;
      *) printf 'unavailable\n' >&2; exit 1 ;;
    esac
    ;;
  up|down)
    printf '%s\n' "$1" >>"$TAILSCALE_POLICY_ACTION_LOG"
    ;;
esac
EOF
chmod +x "$TMP/bin/tailscale"

write_config() {
  cat >"$TMP/config" <<'EOF'
TAILSCALE_NETWORK_POLICY_ENABLED=true
TRUSTED_SSIDS=("Home")
TRUSTED_SUBNETS=("198.51.100.0/24")
TRUSTED_GATEWAYS=()
TRUSTED_DNS_SUFFIXES=()
TRUSTED_MARKER_HOSTS=()
TRUSTED_ACTION="down"
UNTRUSTED_ACTION="up"
EOF
}

run_policy() {
  PATH="$TMP/bin:$PATH" \
  TAILSCALE_POLICY_CONFIG="$TMP/config" \
  TAILSCALE_POLICY_LOCAL_CONFIG="$TMP/missing.local" \
  TAILSCALE_POLICY_STATE_DIR="$TMP/state" \
  TAILSCALE_POLICY_LOCK_DIR="$TMP/state/lock" \
  TAILSCALE_POLICY_STABILIZE_SECONDS=0 \
  TAILSCALE_POLICY_ACTION_LOG="$TMP/actions" \
  TAILSCALE_POLICY_MOCK_IFACE="${TAILSCALE_POLICY_MOCK_IFACE:-}" \
  TAILSCALE_POLICY_MOCK_IP="${TAILSCALE_POLICY_MOCK_IP:-}" \
  TAILSCALE_POLICY_MOCK_GATEWAY="${TAILSCALE_POLICY_MOCK_GATEWAY:-}" \
  TAILSCALE_POLICY_MOCK_SSID="${TAILSCALE_POLICY_MOCK_SSID:-}" \
  TAILSCALE_POLICY_MOCK_DNS_SUFFIXES="${TAILSCALE_POLICY_MOCK_DNS_SUFFIXES:-}" \
  TAILSCALE_POLICY_MOCK_TS_STATE="${TAILSCALE_POLICY_MOCK_TS_STATE:-}" \
  "$SCRIPT" "$@"
}

assert_actions() {
  local expected="$1" actual=""
  [[ -r "$TMP/actions" ]] && actual="$(tr '\n' ' ' <"$TMP/actions" | sed 's/ $//')"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected actions [%s], got [%s]\n' "$expected" "$actual" >&2
    exit 1
  fi
  : >"$TMP/actions"
}

set_mock() {
  export TAILSCALE_POLICY_MOCK_IFACE="$1"
  export TAILSCALE_POLICY_MOCK_IP="$2"
  export TAILSCALE_POLICY_MOCK_SSID="${3:-}"
  export TAILSCALE_POLICY_MOCK_TS_STATE="$4"
  export TAILSCALE_POLICY_MOCK_GATEWAY="${5:-}"
  export TAILSCALE_POLICY_MOCK_DNS_SUFFIXES="${6:-}"
}

: >"$TMP/actions"
write_config

cat >"$TMP/config" <<'EOF'
TAILSCALE_NETWORK_POLICY_ENABLED=false
EOF
set_mock en0 192.0.2.10 Hotel down
run_policy evaluate
assert_actions ""
write_config

set_mock en0 192.0.2.10 Home up
run_policy evaluate
assert_actions "down"

set_mock en0 192.0.2.10 Hotel down
run_policy evaluate
assert_actions "up"

set_mock en7 198.51.100.22 "" up
run_policy evaluate
assert_actions "down"

set_mock utun4 100.90.1.2 "" down
run_policy evaluate
assert_actions ""

set_mock en0 192.0.2.10 Hotel up
run_policy evaluate
assert_actions ""

set_mock en0 192.0.2.10 Hotel down
run_policy evaluate --dry-run >/dev/null
assert_actions ""

run_policy pause 1h >/dev/null
set_mock en0 192.0.2.10 Hotel down
run_policy evaluate >/dev/null
assert_actions ""
run_policy resume >/dev/null

printf 'tailscale-policy tests passed\n'
