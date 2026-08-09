#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
output="${REPO_ROOT}/Examples/S3/threat-modeling/conversation/current-state.normalized.json"
graph="${REPO_ROOT}/Examples/S3/threat-modeling/conversation/current-state.graph.json"

"${REPO_ROOT}/scripts/threat-modeling/normalize-conversation.py" \
  --rules "${REPO_ROOT}/Examples/S3/threat-modeling/conversation-normalization.json" \
  --source "${REPO_ROOT}/Examples/S3/03-session-facilitation.md" \
  --output "${output}"
"${REPO_ROOT}/scripts/threat-modeling/project-conversation-graph.py" \
  --facts "${output}" \
  --output "${graph}"
chmod 0644 "${output}" "${graph}"
printf '[debug] updated reviewed conversation facts at %s\n' "${output}" >&2
