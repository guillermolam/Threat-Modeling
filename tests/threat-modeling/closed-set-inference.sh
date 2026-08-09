#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=../../scripts/ci/common.sh
source "${REPO_ROOT}/scripts/ci/common.sh"
temp_dir="$(make_temp_dir)"
server_pid=""

cleanup() {
  local result=$?
  if [[ -n ${server_pid} ]] && kill -0 "${server_pid}" 2>/dev/null; then
    kill -TERM "${server_pid}"
    set +e
    wait "${server_pid}" 2>/dev/null
    set -e
  fi
  safe_remove_temp_dir "${temp_dir}"
  exit "${result}"
}
trap cleanup EXIT INT TERM

free_port() {
  python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

start_server() {
  local mode="$1"
  local port="$2"
  "${REPO_ROOT}/tests/threat-modeling/fake-ollama.py" \
    --port "${port}" --mode "${mode}" >"${temp_dir}/${mode}.log" 2>&1 &
  server_pid=$!
  for _attempt in $(seq 1 40); do
    if curl --silent --show-error --fail --max-time 1 \
      "http://127.0.0.1:${port}/api/version" >/dev/null 2>&1; then
      return
    fi
    sleep 0.1
  done
  die "fake Ollama did not become ready"
}

stop_server() {
  kill -TERM "${server_pid}"
  set +e
  wait "${server_pid}" 2>/dev/null
  set -e
  server_pid=""
}

run_trial() {
  local port="$1"
  local output="$2"
  local fact_id="${3:-rel-current-04}"
  local expected_binary="${4:-}"
  local command=(
    "${REPO_ROOT}/scripts/threat-modeling/run-closed-set-inference.py"
    --facts "${REPO_ROOT}/Examples/S3/threat-modeling/conversation/current-state.normalized.json"
    --rules "${REPO_ROOT}/Examples/S3/threat-modeling/conversation-normalization.json"
    --classify-prompt "${REPO_ROOT}/Examples/S3/threat-modeling/prompts/classify-atomic-fact.md"
    --slots-prompt "${REPO_ROOT}/Examples/S3/threat-modeling/prompts/select-relation-slots.md"
    --output "${output}"
    --endpoint "http://127.0.0.1:${port}"
    --model qwen3:1.7b
    --expected-digest test-digest
    --fact-id "${fact_id}"
  )
  if [[ -n ${expected_binary} ]]; then
    command+=(--expected-binary-sha256 "${expected_binary}")
  fi
  "${command[@]}"
}

run_corpus() {
  local port="$1"
  local output="$2"
  "${REPO_ROOT}/scripts/threat-modeling/run-closed-set-inference.py" \
    --facts "${REPO_ROOT}/Examples/S3/threat-modeling/conversation/current-state.normalized.json" \
    --rules "${REPO_ROOT}/Examples/S3/threat-modeling/conversation-normalization.json" \
    --classify-prompt "${REPO_ROOT}/Examples/S3/threat-modeling/prompts/classify-atomic-fact.md" \
    --slots-prompt "${REPO_ROOT}/Examples/S3/threat-modeling/prompts/select-relation-slots.md" \
    --output "${output}" \
    --endpoint "http://127.0.0.1:${port}" \
    --model qwen3:1.7b \
    --expected-digest test-digest
}

pass_port="$(free_port)"
start_server pass "${pass_port}"
run_trial "${pass_port}" "${temp_dir}/pass.json"
jq -e '.accepted | length == 1' "${temp_dir}/pass.json" >/dev/null
jq -e '.review_queue | length == 0' "${temp_dir}/pass.json" >/dev/null
set +e
run_corpus "${pass_port}" "${temp_dir}/corpus.json" \
  2>"${temp_dir}/expected-corpus-evidence.log"
corpus_status=$?
set -e
[[ ${corpus_status} -ne 0 ]] || die "full corpus accepted a missing-evidence fact"
jq -e '.accepted | length == 14' "${temp_dir}/corpus.json" >/dev/null
jq -e '.review_queue == [{"fact_id":"unc-current-01","reason":"evidence-missing","state":"unknown"}]' \
  "${temp_dir}/corpus.json" >/dev/null
rg --fixed-strings --line-regexp \
  '[error] closed-set inference produced review-queue items' \
  "${temp_dir}/expected-corpus-evidence.log" >/dev/null
stop_server

pin_port="$(free_port)"
start_server pass "${pin_port}"
set +e
run_trial "${pin_port}" "${temp_dir}/wrong-pin.json" rel-current-04 wrong-binary-hash \
  2>"${temp_dir}/expected-binary-pin.log"
pin_status=$?
set -e
[[ ${pin_status} -ne 0 ]] || die "wrong Ollama binary pin was accepted"
rg --fixed-strings \
  '[error] Ollama binary hash mismatch: expected wrong-binary-hash, got ' \
  "${temp_dir}/expected-binary-pin.log" >/dev/null
stop_server

missing_port="$(free_port)"
start_server pass "${missing_port}"
set +e
run_trial "${missing_port}" "${temp_dir}/missing.json" unc-current-01 \
  2>"${temp_dir}/expected-missing-evidence.log"
missing_status=$?
set -e
[[ ${missing_status} -ne 0 ]] || die "missing evidence was accepted"
rg --fixed-strings --line-regexp \
  '[error] closed-set inference produced review-queue items' \
  "${temp_dir}/expected-missing-evidence.log" >/dev/null
jq -e '.review_queue == [{"fact_id":"unc-current-01","reason":"evidence-missing","state":"unknown"}]' \
  "${temp_dir}/missing.json" >/dev/null
stop_server

disagree_port="$(free_port)"
start_server disagree "${disagree_port}"
set +e
run_trial "${disagree_port}" "${temp_dir}/disagree.json" \
  2>"${temp_dir}/expected-rejection.log"
trial_status=$?
set -e
[[ ${trial_status} -ne 0 ]] || die "nonreproducible slots were accepted"
rg --fixed-strings --line-regexp \
  '[error] closed-set inference produced review-queue items' \
  "${temp_dir}/expected-rejection.log" >/dev/null
jq -e '.review_queue[0].reason == "slots-nonreproducible"' \
  "${temp_dir}/disagree.json" >/dev/null
stop_server
debug "closed-set inference passes exact agreement and fails closed on drift"
