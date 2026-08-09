#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
start_script="${REPO_ROOT}/scripts/llm/start-ollama.sh"
stop_script="${REPO_ROOT}/scripts/llm/stop-ollama.sh"
wrapper_script="${REPO_ROOT}/scripts/llm/with-ollama.sh"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/threat-modeling-llm.XXXXXX")"

cleanup() {
  local status=$?
  if [[ -f ${temp_dir}/external.pid ]]; then
    local external_cleanup_pid
    external_cleanup_pid="$(<"${temp_dir}/external.pid")"
    if kill -0 "${external_cleanup_pid}" 2>/dev/null; then
      kill -TERM "${external_cleanup_pid}"
      set +e
      wait "${external_cleanup_pid}" 2>/dev/null
      set -e
    fi
  fi
  if [[ -f ${temp_dir}/owned-state/pid ]]; then
    local owned_cleanup_pid
    owned_cleanup_pid="$(<"${temp_dir}/owned-state/pid")"
    if kill -0 "${owned_cleanup_pid}" 2>/dev/null; then
      kill -TERM "${owned_cleanup_pid}"
      set +e
      wait "${owned_cleanup_pid}" 2>/dev/null
      set -e
    fi
  fi
  rm -rf -- "${temp_dir}"
  exit "${status}"
}
trap cleanup EXIT INT TERM

cat >"${temp_dir}/ollama" <<'FAKE_OLLAMA'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == serve ]] || exit 2
port="${OLLAMA_HOST##*:}"
exec python3 "$(dirname "$0")/ollama-serve.py" "${port}"
FAKE_OLLAMA
chmod 0755 "${temp_dir}/ollama"

cat >"${temp_dir}/ollama-serve.py" <<'PY'
import http.server
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"version":"test"}')

    def log_message(self, _format, *_args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PY

cat >"${temp_dir}/capture-pid" <<'CAPTURE_PID'
#!/usr/bin/env bash
set -euo pipefail
[[ -f $1 ]]
cp "$1" "$2"
CAPTURE_PID
chmod 0755 "${temp_dir}/capture-pid"

cat >"${temp_dir}/capture-and-fail" <<'CAPTURE_AND_FAIL'
#!/usr/bin/env bash
set -euo pipefail
[[ -f $1 ]]
cp "$1" "$2"
exit 23
CAPTURE_AND_FAIL
chmod 0755 "${temp_dir}/capture-and-fail"

free_port() {
  python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

owned_port="$(free_port)"
OLLAMA_BIN="${temp_dir}/ollama" \
  OLLAMA_HOST="127.0.0.1:${owned_port}" \
  OLLAMA_RUNTIME_DIR="${temp_dir}/owned-state" \
  "${wrapper_script}" "${temp_dir}/capture-pid" \
  "${temp_dir}/owned-state/pid" "${temp_dir}/owned.pid"
owned_pid="$(<"${temp_dir}/owned.pid")"
[[ ! -f ${temp_dir}/owned-state/owner ]] || {
  printf '[error] owned lifecycle marker survived wrapper cleanup\n' >&2
  exit 1
}
[[ -z ${owned_pid} ]] || ! kill -0 "${owned_pid}" 2>/dev/null || {
  printf '[error] repository-owned service survived wrapper cleanup\n' >&2
  exit 1
}

failure_port="$(free_port)"
set +e
OLLAMA_BIN="${temp_dir}/ollama" \
  OLLAMA_HOST="127.0.0.1:${failure_port}" \
  OLLAMA_RUNTIME_DIR="${temp_dir}/failure-state" \
  "${wrapper_script}" "${temp_dir}/capture-and-fail" \
  "${temp_dir}/failure-state/pid" "${temp_dir}/failure.pid"
failure_status=$?
set -e
[[ ${failure_status} -eq 23 ]] || {
  printf '[error] wrapper changed consumer exit 23 to %s\n' "${failure_status}" >&2
  exit 1
}
failure_pid="$(<"${temp_dir}/failure.pid")"
[[ ! -f ${temp_dir}/failure-state/owner ]] || {
  printf '[error] failed-command lifecycle marker survived cleanup\n' >&2
  exit 1
}
! kill -0 "${failure_pid}" 2>/dev/null || {
  printf '[error] repository-owned service survived failed command\n' >&2
  exit 1
}

external_port="$(free_port)"
python3 "${temp_dir}/ollama-serve.py" "${external_port}" >"${temp_dir}/external.log" 2>&1 &
external_pid=$!
printf '%s\n' "${external_pid}" >"${temp_dir}/external.pid"
for _attempt in $(seq 1 40); do
  curl --silent --fail --max-time 1 "http://127.0.0.1:${external_port}/api/version" >/dev/null 2>&1 && break
  sleep 0.1
done

OLLAMA_BIN="${temp_dir}/ollama" \
  OLLAMA_HOST="127.0.0.1:${external_port}" \
  OLLAMA_RUNTIME_DIR="${temp_dir}/external-state" \
  "${start_script}"
OLLAMA_HOST="127.0.0.1:${external_port}" \
  OLLAMA_RUNTIME_DIR="${temp_dir}/external-state" \
  "${stop_script}"
kill -0 "${external_pid}" 2>/dev/null || {
  printf '[error] pre-existing service was stopped\n' >&2
  exit 1
}

invalid_port="$(free_port)"
if OLLAMA_BIN="${temp_dir}/ollama" \
  OLLAMA_HOST="0.0.0.0:${invalid_port}" \
  OLLAMA_RUNTIME_DIR="${temp_dir}/invalid-state" \
  "${start_script}" >/dev/null 2>&1; then
  printf '[error] non-loopback bind was accepted\n' >&2
  exit 1
fi

printf '[debug] Ollama lifecycle contracts passed\n'
