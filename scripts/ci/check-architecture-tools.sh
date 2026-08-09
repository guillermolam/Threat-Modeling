#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../config/tool-versions.env
source "${REPO_ROOT}/config/tool-versions.env"
export PATH="${REPO_ROOT}/.tools/bin:${PATH}"

check_version() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  printf '[debug] %s expected=%s actual=%s\n' "${name}" "${expected}" "${actual}" >&2
  [[ ${actual} == "${expected}" ]] || {
    printf '[error] %s: expected %s, got %s\n' "${name}" "${expected}" "${actual}" >&2
    exit 1
  }
}

tofu_version_json="$(tofu version -json)"
tofu_version="$(jq -er .terraform_version <<<"${tofu_version_json}")"
terragrunt_version_output="$(terragrunt --version)"
terragrunt_version="$(sed -E 's/.*v([0-9.]+).*/\1/' <<<"${terragrunt_version_output}")"
floci_version_output="$(floci version)"
floci_version="$(awk '/Floci CLI/{print $3}' <<<"${floci_version_output}")"
aws_version_output="$(aws --version 2>&1)"
aws_version="$(sed -E 's#aws-cli/([^ ]+).*#\1#' <<<"${aws_version_output}")"
go_version_output="$(go version)"
go_version="$(awk '{sub(/^go/, "", $3); print $3}' <<<"${go_version_output}")"
d2_version_output="$(d2 --version)"
d2_version="$(sed -E 's/.*v([0-9.]+).*/\1/' <<<"${d2_version_output}")"
plantuml_version_output="$(plantuml --about)"
plantuml_version="$(awk '/PlantUML version/{print $3; exit}' <<<"${plantuml_version_output}")"

check_version opentofu "${OPENTOFU_VERSION}" "${tofu_version}"
check_version terragrunt "${TERRAGRUNT_VERSION}" "${terragrunt_version}"
check_version floci-cli "${FLOCI_CLI_VERSION}" "${floci_version}"
check_version aws-cli "${AWS_CLI_VERSION}" "${aws_version}"
check_version go "${GO_VERSION}" "${go_version}"
check_version d2 "${D2_VERSION}" "${d2_version}"
check_version plantuml "${PLANTUML_VERSION}" "${plantuml_version}"

awsdac_path="$(command -v awsdac)"
awsdac_build="$(go version -m "${awsdac_path}")"
awsdac_module="$(awk '$1 == "mod" {print $3}' <<<"${awsdac_build}")"
printf '[debug] awsdac module version=%s expected-commit=%s\n' \
  "${awsdac_module}" "${AWSDAC_COMMIT}" >&2
[[ ${awsdac_module} == *"${AWSDAC_COMMIT:0:12}"* ]] || {
  printf '[error] awsdac was not built from commit %s\n' "${AWSDAC_COMMIT}" >&2
  exit 1
}
printf '[debug] Architecture toolchain matches the pinned contract\n' >&2
