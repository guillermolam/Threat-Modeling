#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../ci/common.sh
source "${SCRIPT_DIR}/../ci/common.sh"

remote_name="${1:-unknown}"
stdin_path="${3:-}"
[[ -n ${stdin_path} && -r ${stdin_path} ]] || die "pre-push requires Trunk's readable hook input file"
debug "pre-push: remote=${remote_name}; validating pinned tools"
"${SCRIPT_DIR}/../ci/check-tools.sh"

ref_count=0
while read -r local_ref local_oid remote_ref remote_oid; do
  [[ -n ${local_ref:-} ]] || continue
  ref_count=$((ref_count + 1))
  if [[ ${local_oid} =~ ^0+$ ]]; then
    debug "pre-push: ${remote_ref} is being deleted; no new objects to scan"
    continue
  fi

  debug "pre-push: scanning ${local_ref} -> ${remote_ref}"
  "${SCRIPT_DIR}/../ci/scan-commit-range.sh" "${remote_oid}" "${local_oid}"
  "${SCRIPT_DIR}/../ci/zizmor-if-changed.sh" "${remote_oid}" "${local_oid}"
done <"${stdin_path}"

[[ ${ref_count} -gt 0 ]] || die "pre-push received no ref update records"
debug "pre-push: all outgoing refs passed"
