#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"

ollama_bin="${OLLAMA_BIN:-}"
curl_bin="${CURL_BIN:-}"
if [[ -z ${ollama_bin} ]]; then
  ollama_bin="$(command -v ollama)" || die "ollama executable not found"
fi
if [[ -z ${curl_bin} ]]; then
  curl_bin="$(command -v curl)" || die "curl executable not found"
fi
ollama_host="${OLLAMA_HOST:-127.0.0.1:11434}"
runtime_dir="${OLLAMA_RUNTIME_DIR:-${REPO_ROOT}/.tools/runtime/ollama}"
owner_file="${runtime_dir}/owner"
pid_file="${runtime_dir}/pid"
log_file="${runtime_dir}/ollama-debug.log"

[[ ${ollama_host} =~ ^(127\.0\.0\.1|localhost):[0-9]+$ ]] ||
  die "OLLAMA_HOST must be a loopback hostname and explicit port: ${ollama_host}"
[[ -n ${ollama_bin} && -x ${ollama_bin} ]] || die "ollama executable not found"
[[ -n ${curl_bin} && -x ${curl_bin} ]] || die "curl executable not found"

mkdir -p "${runtime_dir}"

healthy() {
  "${curl_bin}" --silent --show-error --fail --max-time 1 \
    "http://${ollama_host}/api/version" >/dev/null 2>&1
}

set +e
healthy
health_status=$?
set -e
if ((health_status == 0)); then
  printf 'external\n' >"${owner_file}"
  rm -f -- "${pid_file}"
  debug "using pre-existing Ollama at ${ollama_host}; repository will not stop it"
  exit 0
fi

: >"${log_file}"
debug "starting repository-owned Ollama at ${ollama_host}; debug log: ${log_file}"
OLLAMA_DEBUG=1 \
  OLLAMA_HOST="${ollama_host}" \
  OLLAMA_KEEP_ALIVE=0s \
  OLLAMA_NUM_PARALLEL=1 \
  OLLAMA_CONTEXT_LENGTH=4096 \
  OLLAMA_NO_CLOUD=1 \
  "${ollama_bin}" serve >>"${log_file}" 2>&1 &
ollama_pid=$!
printf '%s\n' "${ollama_pid}" >"${pid_file}"
printf 'repository\n' >"${owner_file}"

for _attempt in $(seq 1 60); do
  set +e
  healthy
  health_status=$?
  set -e
  if ((health_status == 0)); then
    debug "repository-owned Ollama is ready (pid ${ollama_pid})"
    exit 0
  fi
  if ! kill -0 "${ollama_pid}" 2>/dev/null; then
    debug "Ollama debug log follows"
    sed 's/^/[ollama] /' "${log_file}" >&2
    die "Ollama exited before becoming ready"
  fi
  sleep 0.25
done

if kill -0 "${ollama_pid}" 2>/dev/null; then
  kill -TERM "${ollama_pid}"
fi
set +e
wait "${ollama_pid}" 2>/dev/null
wait_status=$?
set -e
debug "Ollama timeout cleanup wait status: ${wait_status}"
debug "Ollama debug log follows"
sed 's/^/[ollama] /' "${log_file}" >&2
die "Ollama did not become ready within 15 seconds"
