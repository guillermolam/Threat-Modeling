#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../../config/tool-versions.env
source "${REPO_ROOT}/config/tool-versions.env"
ollama_host="${OLLAMA_HOST:-127.0.0.1:11434}"
output="${REPO_ROOT}/.tools/runtime/ollama/closed-set/report.json"
fact_id="${1:-rel-current-04}"

mkdir -p "$(dirname "${output}")"
"${REPO_ROOT}/scripts/threat-modeling/run-closed-set-inference.py" \
  --facts "${REPO_ROOT}/Examples/S3/threat-modeling/conversation/current-state.normalized.json" \
  --rules "${REPO_ROOT}/Examples/S3/threat-modeling/conversation-normalization.json" \
  --classify-prompt "${REPO_ROOT}/Examples/S3/threat-modeling/prompts/classify-atomic-fact.md" \
  --slots-prompt "${REPO_ROOT}/Examples/S3/threat-modeling/prompts/select-relation-slots.md" \
  --output "${output}" \
  --endpoint "http://${ollama_host}" \
  --model qwen3:1.7b \
  --expected-digest "${OLLAMA_QWEN3_17_DIGEST}" \
  --expected-binary-sha256 "${OLLAMA_BINARY_SHA256}" \
  --fact-id "${fact_id}"
printf '[debug] closed-set trial report: %s\n' "${output}" >&2
