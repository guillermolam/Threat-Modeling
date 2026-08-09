#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"

input_dir="${1:-${REPO_ROOT}/Examples/S3/threat-modeling/dfd}"
[[ -d ${input_dir} ]] || die "DFD input directory does not exist: ${input_dir}"
docker version >/dev/null

for posture in current-state target-state; do
  input_file="${input_dir}/${posture}.mmd"
  [[ -f ${input_file} ]] || die "missing Mermaid input: ${input_file}"
  debug "compiling ${posture} Mermaid to SVG and PNG"
  for extension in svg png; do
    docker run --rm --network none \
      --volume "${input_dir}:/data" \
      "${MERMAID_CLI_IMAGE}" \
      --input "${posture}.mmd" \
      --output "${posture}.mermaid.${extension}" \
      --configFile /data/mermaid-config.json \
      --backgroundColor transparent
  done

  d2_input="${input_dir}/${posture}.d2"
  [[ -f ${d2_input} ]] || die "missing D2 input: ${d2_input}"
  debug "validating and compiling ${posture} D2 to SVG"
  d2 validate "${d2_input}"
  d2 fmt --check "${d2_input}"
  # D2 PNG delegates to a runtime-downloaded Playwright driver. SVG keeps this
  # offline contract deterministic and avoids an unpinned browser dependency.
  d2 --debug --layout elk --theme 0 --pad 40 --omit-version \
    "${d2_input}" "${input_dir}/${posture}.d2.svg"

  plantuml_input="${input_dir}/${posture}.puml"
  [[ -f ${plantuml_input} ]] || die "missing PlantUML input: ${plantuml_input}"
  debug "validating and compiling ${posture} PlantUML to SVG and PNG"
  plantuml --check-syntax "${plantuml_input}"
  for extension in svg png; do
    plantuml --format "${extension}" --output-dir "${input_dir}" "${plantuml_input}"
    mv "${input_dir}/${posture}.${extension}" \
      "${input_dir}/${posture}.plantuml.${extension}"
  done
done
