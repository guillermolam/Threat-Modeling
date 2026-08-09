#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../../scripts/ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"
temp_dir="$(make_temp_dir)"

cleanup() {
  local status=$?
  safe_remove_temp_dir "${temp_dir}"
  exit "${status}"
}
trap cleanup EXIT INT TERM

generated_dir="${temp_dir}/dfd"
mkdir -p "${generated_dir}"
cp "${REPO_ROOT}/Examples/S3/threat-modeling/mermaid-config.json" \
  "${generated_dir}/mermaid-config.json"
"${REPO_ROOT}/scripts/threat-modeling/generate-dfds.py" \
  --model "${REPO_ROOT}/Examples/S3/architecture/model-tags.json" \
  --output "${generated_dir}"

for posture in current-state target-state; do
  for extension in mmd d2 puml; do
    cmp "${generated_dir}/${posture}.${extension}" \
      "${REPO_ROOT}/Examples/S3/threat-modeling/dfd/${posture}.${extension}"
  done
done

"${REPO_ROOT}/tests/threat-modeling/dfd-contracts.py" \
  --model "${REPO_ROOT}/Examples/S3/architecture/model-tags.json" \
  --dfd-dir "${generated_dir}"
"${REPO_ROOT}/scripts/threat-modeling/render-dfds.sh" "${generated_dir}"

for posture in current-state target-state; do
  for output in \
    "${posture}.mermaid.svg" \
    "${posture}.mermaid.png" \
    "${posture}.d2.svg" \
    "${posture}.plantuml.svg" \
    "${posture}.plantuml.png"; do
    test -s "${generated_dir}/${output}"
  done
done
debug "DFD IR conversions, graph coverage, SVG, and PNG contracts passed"
