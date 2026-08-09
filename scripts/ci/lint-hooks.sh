#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

scripts=(
  "${REPO_ROOT}"/scripts/architecture/*.sh
  "${REPO_ROOT}"/scripts/ci/*.sh
  "${REPO_ROOT}"/scripts/hooks/*.sh
  "${REPO_ROOT}"/tests/architecture/*.sh
  "${REPO_ROOT}"/tests/hooks/*.sh
)

debug "Checking Bash syntax for ${#scripts[@]} scripts"
for script in "${scripts[@]}"; do
  bash -n "${script}"
done

debug "Running Trunk linters without autofix; every diagnostic is fatal"
trunk --ci --verbose check --no-fix \
  "${REPO_ROOT}/.github" \
  "${REPO_ROOT}/.trunk/trunk.yaml" \
  "${REPO_ROOT}/Taskfile.yml" \
  "${REPO_ROOT}/config" \
  "${REPO_ROOT}/scripts/architecture" \
  "${REPO_ROOT}/scripts/ci" \
  "${REPO_ROOT}/scripts/hooks" \
  "${REPO_ROOT}/tests/architecture" \
  "${REPO_ROOT}/tests/hooks"

if [[ -n ${HEAD_SHA:-} ]]; then
  require_commit "${HEAD_SHA}"
  if [[ -z ${BASE_SHA:-} || ${BASE_SHA} =~ ^0+$ ]]; then
    debug "Checking ${HEAD_SHA} for whitespace errors as a root selection"
    git -C "${REPO_ROOT}" diff-tree --check --root -r "${HEAD_SHA}"
  else
    require_commit "${BASE_SHA}"
    debug "Checking ${BASE_SHA}..${HEAD_SHA} for whitespace errors"
    git -C "${REPO_ROOT}" diff --check "${BASE_SHA}" "${HEAD_SHA}"
  fi
else
  debug "Checking staged and unstaged changes for whitespace errors"
  git -C "${REPO_ROOT}" diff --cached --check
  git -C "${REPO_ROOT}" diff --check
fi
debug "Trunk and hook lint completed with zero diagnostics"
