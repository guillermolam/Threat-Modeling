#!/usr/bin/env bash
set -euo pipefail

FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"

case "${FLOCI_ENDPOINT}" in
  http://localhost:[0-9]* | http://127.0.0.1:[0-9]*) ;;
  *)
    echo "Refusing non-local FLOCI_ENDPOINT: ${FLOCI_ENDPOINT}" >&2
    echo "This lab is intentionally pinned to local Floci." >&2
    exit 1
    ;;
esac

for command_name in floci docker aws tofu terragrunt curl jq; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_EC2_METADATA_DISABLED=true

curl -fsS "${FLOCI_ENDPOINT}/" >/dev/null
aws --endpoint-url "${FLOCI_ENDPOINT}" sts get-caller-identity >/dev/null

echo "Floci endpoint: ${FLOCI_ENDPOINT}"
floci status \
  --container "${FLOCI_CONTAINER:-floci}" \
  --endpoint "${FLOCI_ENDPOINT}" \
  --no-color
tofu version | head -n 1
terragrunt --version
aws --version
echo "Preflight passed: all AWS calls are pinned to local Floci."
