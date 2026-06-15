#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# DEPRECATED — kept for one release cycle to avoid breaking muscle-memory.
#
# The monolithic installer has been decomposed into:
#   scripts/lib.sh, detect-os.sh, select-profile.sh, install-packages.sh,
#   apply-stow.sh, enable-services.sh
# all orchestrated by the repo-root ./bootstrap.sh.
#
# This shim simply forwards to ../bootstrap.sh. It will be removed next cycle.
# ============================================================

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"

printf "%s\n" "NOTE: scripts/install.sh is deprecated; forwarding to ./bootstrap.sh" >&2

exec bash "$REPO_DIR/bootstrap.sh" "$@"
