#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"

dfd_dir="${REPO_ROOT}/Examples/S3/threat-modeling/dfd"
mkdir -p "${dfd_dir}"
cp "${REPO_ROOT}/Examples/S3/threat-modeling/mermaid-config.json" \
  "${dfd_dir}/mermaid-config.json"
"${REPO_ROOT}/scripts/threat-modeling/generate-dfds.py" \
  --model "${REPO_ROOT}/Examples/S3/architecture/model-tags.json" \
  --output "${dfd_dir}"
"${REPO_ROOT}/scripts/threat-modeling/render-dfds.sh" "${dfd_dir}"
chmod 0644 "${dfd_dir}"/*
debug "updated compiled DFD artifacts in ${dfd_dir}"
