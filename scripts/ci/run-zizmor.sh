#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

input_path="${1:-${REPO_ROOT}}"
config_path="${input_path}/.github/zizmor.yml"
[[ -f ${config_path} ]] || die "Missing Zizmor configuration: ${config_path}"

debug "Zizmor ${ZIZMOR_VERSION}: offline, pedantic, strict collection, ignores disabled"
zizmor \
  --offline \
  --pedantic \
  --strict-collection \
  --no-ignores \
  --config "${config_path}" \
  --color never \
  --no-progress \
  --show-audit-urls=always \
  -vv \
  "${input_path}"
debug "Zizmor completed with zero findings and zero collection errors"
