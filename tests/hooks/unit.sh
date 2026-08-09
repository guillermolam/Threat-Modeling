#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../scripts/ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"

tests_run=0

pass_test() {
  tests_run=$((tests_run + 1))
  printf 'PASS  %s\n' "$1"
}

assert_true() {
  local description="$1"
  shift
  "$@" || die "Test failed: ${description}"
  pass_test "${description}"
}

assert_false() {
  local description="$1"
  shift
  if "$@"; then
    die "Test failed: ${description}"
  fi
  pass_test "${description}"
}

github_paths_touch() {
  printf '%s\n' '.github/workflows/quality.yml' 'README.md' | path_touches_github
}

ordinary_paths_touch() {
  printf '%s\n' 'README.md' 'Examples/S3/06-stride.md' | path_touches_github
}

assert_true '.github workflow changes require Zizmor' \
  github_paths_touch
assert_false 'ordinary paths do not require Zizmor' \
  ordinary_paths_touch
assert_true 'forty-zero Git OID is recognized' \
  is_zero_oid '0000000000000000000000000000000000000000'
assert_false 'a real Git OID is not treated as zero' \
  is_zero_oid '5e37dbecc06199e522c5eb3c143eaae1de7ec174'

actual_paths="$(changed_paths HEAD~1 HEAD)"
[[ -n ${actual_paths} ]] || die 'Test failed: changed_paths returned no committed files'
pass_test 'changed_paths returns the requested Git range'

printf 'PASS  %d hook unit tests\n' "${tests_run}"
