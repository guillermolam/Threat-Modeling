#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../../scripts/ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"
temp_dir="$(make_temp_dir)"

cleanup() {
  local result=$?
  safe_remove_temp_dir "${temp_dir}"
  exit "${result}"
}
trap cleanup EXIT INT TERM

facts="${temp_dir}/current-state.normalized.json"
graph="${temp_dir}/current-state.graph.json"
system="${REPO_ROOT}/Examples/S3/threat-modeling/formal-system.json"
rules="${REPO_ROOT}/Examples/S3/threat-modeling/conversation-normalization.json"
"${REPO_ROOT}/scripts/threat-modeling/validate-formal-system.py" \
  --system "${system}" \
  --rules "${rules}"
"${REPO_ROOT}/scripts/threat-modeling/normalize-conversation.py" \
  --rules "${rules}" \
  --source "${REPO_ROOT}/Examples/S3/03-session-facilitation.md" \
  --output "${facts}"
cmp "${facts}" \
  "${REPO_ROOT}/Examples/S3/threat-modeling/conversation/current-state.normalized.json"
"${REPO_ROOT}/scripts/threat-modeling/project-conversation-graph.py" \
  --facts "${facts}" \
  --output "${graph}"
cmp "${graph}" \
  "${REPO_ROOT}/Examples/S3/threat-modeling/conversation/current-state.graph.json"
"${REPO_ROOT}/scripts/threat-modeling/validate-graph-projection.py" \
  --facts "${facts}" \
  --graph "${graph}"
"${REPO_ROOT}/tests/threat-modeling/conversation-normalization.py" \
  --facts "${facts}" \
  --system "${system}" \
  --rules "${rules}" \
  --source "${REPO_ROOT}/Examples/S3/03-session-facilitation.md"
