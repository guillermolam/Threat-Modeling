#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PIPELINE="${SCRIPT_DIR}/model_pipeline.py"
CATALOG="${REPO_ROOT}/Examples/S3/architecture/model-tags.json"
DEFINITION="Examples/S3/architecture/definition-meridian.yaml"

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 3 ]] || die "usage: $0 <current-state|target-state> <evidence-dir> <output-dir>"
posture="$1"
evidence_dir="$2"
output_dir="$3"
[[ ${posture} == current-state || ${posture} == target-state ]] ||
  die "posture must be current-state or target-state"
[[ ${evidence_dir} == /* && ${output_dir} == /* ]] ||
  die "evidence-dir and output-dir must be absolute paths"

for command in awsdac python3; do
  command -v "${command}" >/dev/null || die "required command not found: ${command}"
done

printf '[debug] compiling %s blueprint from sanitized evidence\n' "${posture}" >&2
python3 "${PIPELINE}" compile \
  --catalog "${CATALOG}" \
  --posture "${posture}" \
  --evidence-dir "${evidence_dir}" \
  --output-dir "${output_dir}" \
  --definition-file "${DEFINITION}"

python3 "${PIPELINE}" validate-blueprint "${output_dir}/blueprint.json"
jq empty "${output_dir}/awsdac.yaml"

render_log="${output_dir}/awsdac.log"
printf '[debug] rendering %s through awsdac\n' "${output_dir}/awsdac.yaml" >&2
(cd "${REPO_ROOT}" && awsdac "${output_dir}/awsdac.yaml" \
  --force --verbose --output "${output_dir}/architecture.png" \
  >"${render_log}" 2>&1)
if rg --line-number '(^|[[:space:]])(WARN|WARNING|Warning)([[:space:]:]|$)' "${render_log}"; then
  die "awsdac emitted a warning"
fi
[[ -s ${output_dir}/architecture.png ]] || die "awsdac did not create a diagram"
file "${output_dir}/architecture.png" | rg --quiet 'PNG image data' ||
  die "awsdac output is not a PNG"
printf '[debug] blueprint and diagram passed validation\n' >&2
