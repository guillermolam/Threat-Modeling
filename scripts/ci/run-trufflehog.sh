#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

[[ $# -gt 0 ]] || die "run-trufflehog.sh requires a source and its arguments"

output_dir="$(make_temp_dir)"
trap 'safe_remove_temp_dir "${output_dir}"' EXIT
findings_file="${output_dir}/findings.jsonl"

debug "TruffleHog ${TRUFFLEHOG_VERSION}: offline detection, debug level 1, redacted output"
if trufflehog \
  --no-update \
  --no-verification \
  --results=unverified \
  --fail \
  --fail-on-scan-errors \
  --log-level=1 \
  --no-color \
  --json \
  "$@" >"${findings_file}"; then
  status=0
else
  status=$?
fi

if [[ -s ${findings_file} ]]; then
  jq -r '
    "[finding] detector=\(.DetectorName // "unknown")" +
    " verified=\(.Verified // false)" +
    " file=\(.SourceMetadata.Data.Filesystem.file // .SourceMetadata.Data.Git.file // "unknown")" +
    " line=\(.SourceMetadata.Data.Filesystem.line // .SourceMetadata.Data.Git.line // "unknown")"
  ' "${findings_file}" >&2
fi

[[ ${status} -eq 0 ]] || exit "${status}"
debug "TruffleHog completed with zero findings and zero scan errors"
