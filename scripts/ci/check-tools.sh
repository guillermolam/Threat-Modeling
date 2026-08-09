#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_version() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  [[ ${actual} == "${expected}" ]] ||
    die "${name}: expected ${expected}, got ${actual}"
  debug "${name}=${actual}"
}

for command_name in task trunk betterleaks trufflehog zizmor git jq; do
  command -v "${command_name}" >/dev/null 2>&1 ||
    die "Missing required command: ${command_name}"
done

task_actual="$(task --version)"
trunk_actual="$(trunk --version)"
betterleaks_actual="$(betterleaks version)"
trufflehog_actual="$(trufflehog --version)"
zizmor_actual="$(zizmor --version)"

require_version task "${TASK_VERSION}" "${task_actual}"
require_version trunk "${TRUNK_VERSION}" "${trunk_actual}"
require_version betterleaks "${BETTERLEAKS_VERSION}" "${betterleaks_actual}"
require_version trufflehog "trufflehog ${TRUFFLEHOG_VERSION}" "${trufflehog_actual}"
require_version zizmor "zizmor ${ZIZMOR_VERSION}" "${zizmor_actual}"

debug "All pinned CI tools are available"
