#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

base_oid="${1:-}"
head_oid="${2:-HEAD}"
require_commit "${head_oid}"
if [[ -n ${base_oid} && ! ${base_oid} =~ ^0+$ ]]; then
  require_commit "${base_oid}"
fi

paths_file="$(mktemp "${TMPDIR:-/tmp}/threat-modeling-paths.XXXXXX")"
snapshot_dir="$(make_temp_dir)"
cleanup() {
  rm -f -- "${paths_file}"
  safe_remove_temp_dir "${snapshot_dir}"
}
trap cleanup EXIT

changed_paths "${base_oid}" "${head_oid}" >"${paths_file}"
if ! grep -qE '^\.github/' "${paths_file}"; then
  debug "Commit selection does not touch .github/; Zizmor not required"
  exit 0
fi

debug "Commit selection touches .github/; Zizmor is mandatory"
github_tree="$(git -C "${REPO_ROOT}" ls-tree -r --name-only "${head_oid}" -- .github)"
if [[ -z ${github_tree} ]]; then
  debug "The selected commit deletes all auditable .github inputs"
  exit 0
fi

git -C "${REPO_ROOT}" archive "${head_oid}" -- .github | tar -x -C "${snapshot_dir}"
"${SCRIPT_DIR}/run-zizmor.sh" "${snapshot_dir}"
