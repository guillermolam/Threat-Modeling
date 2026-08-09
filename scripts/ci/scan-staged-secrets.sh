#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

if git -C "${REPO_ROOT}" diff --cached --quiet --exit-code; then
  debug "No staged changes; staged secret scan has no input"
  exit 0
fi

debug "Betterleaks ${BETTERLEAKS_VERSION}: scanning staged Git content"
betterleaks git \
  --staged \
  --log-level debug \
  --redact=100 \
  --ignore-gitleaks-allow \
  --no-banner \
  --no-color \
  "${REPO_ROOT}"

snapshot_dir="$(make_temp_dir)"
trap 'safe_remove_temp_dir "${snapshot_dir}"' EXIT
git -C "${REPO_ROOT}" checkout-index --all --prefix="${snapshot_dir}/"
debug "Materialized the Git index without unstaged or untracked files"
"${SCRIPT_DIR}/run-trufflehog.sh" filesystem "${snapshot_dir}"
