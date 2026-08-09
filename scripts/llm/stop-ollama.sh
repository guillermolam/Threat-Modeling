#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"

runtime_dir="${OLLAMA_RUNTIME_DIR:-${REPO_ROOT}/.tools/runtime/ollama}"
owner_file="${runtime_dir}/owner"
pid_file="${runtime_dir}/pid"

if [[ ! -f ${owner_file} ]]; then
  debug "no repository Ollama lifecycle state exists"
  exit 0
fi

owner="$(<"${owner_file}")"
if [[ ${owner} == external ]]; then
  debug "leaving pre-existing Ollama running"
  rm -f -- "${owner_file}" "${pid_file}"
  exit 0
fi

[[ ${owner} == repository ]] || die "invalid Ollama owner marker: ${owner}"
[[ -f ${pid_file} ]] || die "repository-owned Ollama PID is missing"
ollama_pid="$(<"${pid_file}")"
[[ ${ollama_pid} =~ ^[0-9]+$ ]] || die "invalid Ollama PID: ${ollama_pid}"

if kill -0 "${ollama_pid}" 2>/dev/null; then
  process_command="$(ps -p "${ollama_pid}" -o command=)"
  [[ ${process_command} == *ollama* && ${process_command} == *serve* ]] ||
    die "PID ${ollama_pid} is not an Ollama server; refusing to stop it"
  debug "stopping repository-owned Ollama (pid ${ollama_pid})"
  kill -TERM "${ollama_pid}"
  for _attempt in $(seq 1 40); do
    kill -0 "${ollama_pid}" 2>/dev/null || break
    sleep 0.25
  done
  kill -0 "${ollama_pid}" 2>/dev/null &&
    die "repository-owned Ollama did not stop within 10 seconds"
fi

rm -f -- "${owner_file}" "${pid_file}"
debug "repository-owned Ollama lifecycle is stopped"
