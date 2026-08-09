#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

[[ $# -gt 0 ]] || {
  printf '[error] usage: %s command [args...]\n' "$0" >&2
  exit 2
}

"${REPO_ROOT}/scripts/llm/start-ollama.sh"

cleanup() {
  local command_status=$?
  local stop_status
  trap - EXIT INT TERM
  set +e
  "${REPO_ROOT}/scripts/llm/stop-ollama.sh"
  stop_status=$?
  set -e
  if ((command_status != 0)); then
    exit "${command_status}"
  fi
  exit "${stop_status}"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$@"
