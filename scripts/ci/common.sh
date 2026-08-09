#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../../config/tool-versions.env
source "${REPO_ROOT}/config/tool-versions.env"
export PATH="${REPO_ROOT}/.tools/bin:${PATH}"

debug() {
  printf '[debug] %s\n' "$*" >&2
}

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

is_zero_oid() {
  local oid="${1:-}"
  [[ -n ${oid} && ${oid} =~ ^0+$ ]]
}

path_touches_github() {
  local path
  while IFS= read -r path; do
    [[ ${path} == .github/* ]] && return 0
  done
  return 1
}

require_commit() {
  local oid="$1"
  git -C "${REPO_ROOT}" cat-file -e "${oid}^{commit}" 2>/dev/null ||
    die "Not a local commit: ${oid}"
}

changed_paths() {
  local base_oid="$1"
  local head_oid="$2"

  if [[ -z ${base_oid} || ${base_oid} =~ ^0+$ ]]; then
    git -C "${REPO_ROOT}" log --format= --name-only "${head_oid}"
  else
    git -C "${REPO_ROOT}" diff --name-only "${base_oid}" "${head_oid}"
  fi
}

make_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/threat-modeling-ci.XXXXXX"
}

safe_remove_temp_dir() {
  local temp_dir="$1"
  [[ -n ${temp_dir} && -d ${temp_dir} ]] ||
    die "Refusing to remove an invalid temporary directory"
  [[ ${temp_dir} == "${TMPDIR:-/tmp}/threat-modeling-ci."* ]] ||
    die "Refusing to remove unexpected path: ${temp_dir}"
  rm -rf -- "${temp_dir}"
}
