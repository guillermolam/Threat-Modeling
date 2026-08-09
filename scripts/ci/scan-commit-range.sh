#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

base_oid="${1:-}"
head_oid="${2:-HEAD}"
require_commit "${head_oid}"

if [[ -z ${base_oid} || ${base_oid} =~ ^0+$ ]]; then
  log_opts="${head_oid}"
  trufflehog_range=(--branch "${head_oid}")
  debug "Scanning all history reachable from ${head_oid}"
else
  require_commit "${base_oid}"
  log_opts="${base_oid}..${head_oid}"
  trufflehog_range=(--since-commit "${base_oid}" --branch "${head_oid}")
  debug "Scanning commit range ${log_opts}"
fi

debug "Betterleaks ${BETTERLEAKS_VERSION}: Git history scan"
betterleaks git \
  --log-opts="${log_opts}" \
  --log-level debug \
  --redact=100 \
  --ignore-gitleaks-allow \
  --no-banner \
  --no-color \
  "${REPO_ROOT}"

"${SCRIPT_DIR}/run-trufflehog.sh" git "file://${REPO_ROOT}" "${trufflehog_range[@]}"
