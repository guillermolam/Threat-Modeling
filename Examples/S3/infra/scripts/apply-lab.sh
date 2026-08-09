#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SELECTION="${1:-all}"

"${SCRIPT_DIR}/preflight.sh"

export FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_EC2_METADATA_DISABLED=true
TG_LOG_LEVEL="${TG_LOG_LEVEL:-info}"

apply_posture() {
  local posture="$1"
  echo "==> Applying ${posture}"
  terragrunt run \
    --all \
    --source-update \
    --non-interactive \
    --no-color \
    --log-level "${TG_LOG_LEVEL}" \
    --working-dir "${INFRA_DIR}/live/${posture}" \
    -- apply -input=false -auto-approve
}

case "${SELECTION}" in
  current | current-state)
    apply_posture current-state
    ;;
  target | target-state)
    apply_posture target-state
    ;;
  all)
    apply_posture current-state
    apply_posture target-state
    ;;
  *)
    echo "Usage: $0 [current|target|all]" >&2
    exit 2
    ;;
esac
