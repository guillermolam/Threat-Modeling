#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../scripts/ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"

test_dir="$(make_temp_dir)"
trap 'safe_remove_temp_dir "${test_dir}"' EXIT
clean_file="${test_dir}/clean.txt"
candidate_file="${test_dir}/candidate.txt"
printf '%s\n' 'fictional training material with no credential' >"${clean_file}"

# Construct the inert candidate at runtime so the repository never contains a
# credential-shaped fixture. Both engines recognize the GitHub token shape.
candidate="ghp_$(printf '%s' 'Ab3dEf6hIj9LmN2pQr5tUv8xYz1BcD4eFg7H')"
printf 'token=%s\n' "${candidate}" >"${candidate_file}"
unset candidate

better_clean="${test_dir}/better-clean.log"
better_bad="${test_dir}/better-bad.log"
truffle_clean="${test_dir}/truffle-clean.jsonl"
truffle_bad="${test_dir}/truffle-bad.jsonl"

betterleaks dir --log-level debug --redact=100 --ignore-gitleaks-allow \
  --no-banner --no-color "${clean_file}" >"${better_clean}" 2>&1
printf 'PASS  Betterleaks accepts clean input\n'

if betterleaks dir --log-level debug --redact=100 --ignore-gitleaks-allow \
  --no-banner --no-color "${candidate_file}" >"${better_bad}" 2>&1; then
  die 'Betterleaks accepted the synthetic credential'
else
  better_status=$?
fi
[[ ${better_status} -eq 1 ]] ||
  die "Betterleaks returned ${better_status}; expected finding exit code 1"
printf 'PASS  Betterleaks rejects a synthetic credential with exit 1\n'

trufflehog --no-update --no-verification --results=unverified --fail \
  --fail-on-scan-errors --log-level=1 --no-color --json \
  filesystem "${clean_file}" >"${truffle_clean}"
printf 'PASS  TruffleHog accepts clean input\n'

if trufflehog --no-update --no-verification --results=unverified --fail \
  --fail-on-scan-errors --log-level=1 --no-color --json \
  filesystem "${candidate_file}" >"${truffle_bad}"; then
  die 'TruffleHog accepted the synthetic credential'
else
  truffle_status=$?
fi
[[ ${truffle_status} -eq 183 ]] ||
  die "TruffleHog returned ${truffle_status}; expected finding exit code 183"
truffle_lines="$(wc -l <"${truffle_bad}")"
truffle_lines="${truffle_lines// /}"
[[ ${truffle_lines} -gt 0 ]] ||
  die 'TruffleHog returned a finding code without a finding record'
printf 'PASS  TruffleHog rejects a synthetic credential with exit 183\n'
