#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../ci/common.sh
source "${SCRIPT_DIR}/../ci/common.sh"

debug "pre-commit: validating pinned tools"
"${SCRIPT_DIR}/../ci/check-tools.sh"
"${SCRIPT_DIR}/../ci/scan-staged-secrets.sh"

paths_file="$(mktemp "${TMPDIR:-/tmp}/threat-modeling-staged.XXXXXX")"
snapshot_dir="$(make_temp_dir)"
cleanup() {
  rm -f -- "${paths_file}"
  safe_remove_temp_dir "${snapshot_dir}"
}
trap cleanup EXIT

git -C "${REPO_ROOT}" diff --cached --name-only --diff-filter=ACMR >"${paths_file}"
if ! grep -qE '^\.github/' "${paths_file}"; then
  debug "pre-commit: staged paths do not touch .github/; Zizmor not required"
  exit 0
fi

debug "pre-commit: staged paths touch .github/; auditing the exact Git index"
git -C "${REPO_ROOT}" checkout-index --all --prefix="${snapshot_dir}/"
"${SCRIPT_DIR}/../ci/run-zizmor.sh" "${snapshot_dir}"
