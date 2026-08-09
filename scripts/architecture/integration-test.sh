#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../config/tool-versions.env
source "${REPO_ROOT}/config/tool-versions.env"
export PATH="${REPO_ROOT}/.tools/bin:${PATH}"

update=false
if [[ ${1:-} == --update ]]; then
  update=true
  shift
fi
[[ $# -eq 0 ]] || {
  printf '[error] usage: %s [--update]\n' "$0" >&2
  exit 1
}

port="${ARCHITECTURE_FLOCI_PORT:-4567}"
container="${ARCHITECTURE_FLOCI_CONTAINER:-meridian-threat-model-ci}"
endpoint="http://127.0.0.1:${port}"
temp_root="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
work_dir="$(mktemp -d "${temp_root}/meridian-architecture-integration.XXXXXX")"
work_dir="$(cd "${work_dir}" && pwd -P)"
source_copy="${work_dir}/repository"
started=false

cleanup() {
  local status=$?
  if [[ ${started} == true ]]; then
    if ! floci stop --container "${container}" --endpoint "${endpoint}" \
      --timeout 20 --remove --verbose --no-color; then
      printf '[error] failed to stop isolated Floci container %s\n' "${container}" >&2
      status=1
    fi
  fi
  if [[ -d ${work_dir} && ${work_dir} == "${temp_root}/meridian-architecture-integration."* ]]; then
    rm -rf -- "${work_dir}"
  else
    printf '[error] refusing to remove unexpected temporary path: %s\n' "${work_dir}" >&2
    status=1
  fi
  exit "${status}"
}
trap cleanup EXIT

if docker container inspect "${container}" >/dev/null 2>&1; then
  printf '[error] isolated container already exists: %s\n' "${container}" >&2
  exit 1
fi

mkdir -p "${source_copy}"
printf '[debug] copying the working tree without state, caches, tools, or Git metadata\n' >&2
tar -C "${REPO_ROOT}" \
  --exclude=.git \
  --exclude=.tools \
  --exclude=.terraform \
  --exclude=.terragrunt-cache \
  --exclude='*.tfstate' \
  --exclude='*.tfstate.*' \
  -cf - . | tar -C "${source_copy}" -xf -

raw_log="${work_dir}/floci-start.raw.log"
safe_log="${work_dir}/floci-start.log"
printf '[debug] starting isolated Floci %s on %s\n' "${FLOCI_IMAGE}" "${endpoint}" >&2
if floci start \
  --container "${container}" \
  --endpoint "${endpoint}" \
  --port "${port}" \
  --image "${FLOCI_IMAGE}" \
  --pull always \
  --verbose --no-color >"${raw_log}" 2>&1; then
  started=true
else
  status=$?
  if docker container inspect "${container}" >/dev/null 2>&1; then
    started=true
  fi
  python3 "${source_copy}/scripts/architecture/model_pipeline.py" \
    sanitize-log "${raw_log}" "${safe_log}"
  sed -n '1,240p' "${safe_log}" >&2
  printf '[error] Floci start failed with status %s\n' "${status}" >&2
  exit "${status}"
fi
python3 "${source_copy}/scripts/architecture/model_pipeline.py" \
  sanitize-log "${raw_log}" "${safe_log}"
sed -n '1,200p' "${safe_log}" >&2

runtime_version="$(curl --fail --silent --show-error "${endpoint}/_floci/health" | jq -r .version)"
[[ ${runtime_version} == "${FLOCI_RUNTIME_VERSION}" ]] || {
  printf '[error] Floci runtime expected=%s actual=%s\n' \
    "${FLOCI_RUNTIME_VERSION}" "${runtime_version}" >&2
  exit 1
}

run_sanitized() {
  local name="$1"
  shift
  local raw="${work_dir}/${name}.raw.log"
  local safe="${work_dir}/${name}.log"
  printf '[debug] running: %s\n' "$*" >&2
  if "$@" >"${raw}" 2>&1; then
    python3 "${source_copy}/scripts/architecture/model_pipeline.py" sanitize-log "${raw}" "${safe}"
  else
    local status=$?
    python3 "${source_copy}/scripts/architecture/model_pipeline.py" sanitize-log "${raw}" "${safe}"
    sed -n '1,300p' "${safe}" >&2
    printf '[debug] final 300 sanitized log lines follow\n' >&2
    tail -n 300 "${safe}" >&2
    printf '[error] command failed with status %s: %s\n' "${status}" "$*" >&2
    exit "${status}"
  fi
  sed -n '1,240p' "${safe}" >&2
  if rg --line-number '(^|[[:space:]])(WARN|WARNING|Warning)([[:space:]:]|$)' "${safe}"; then
    printf '[error] warning detected in %s\n' "${name}" >&2
    exit 1
  fi
  "${source_copy}/scripts/ci/run-trufflehog.sh" filesystem "${safe}"
}

export FLOCI_ENDPOINT="${endpoint}"
export FLOCI_CONTAINER="${container}"
export TG_LOG_LEVEL=debug
run_sanitized apply-all "${source_copy}/Examples/S3/infra/scripts/apply-lab.sh" all
run_sanitized tofu-validate \
  terragrunt run --all --fail-fast --non-interactive --no-color --log-level debug \
  --working-dir "${source_copy}/Examples/S3/infra" -- \
  validate
run_sanitized verify-all "${source_copy}/Examples/S3/infra/scripts/verify-lab.sh"

for posture in current-state target-state; do
  evidence="${work_dir}/evidence/${posture}"
  output="${source_copy}/Examples/S3/architecture/${posture}"
  "${source_copy}/scripts/architecture/capture-evidence.sh" "${posture}" "${evidence}"
  "${source_copy}/scripts/architecture/compile-blueprint.sh" "${posture}" "${evidence}" "${output}"

  if [[ ${update} == true ]]; then
    printf '[debug] updating reviewed %s generated artifacts\n' "${posture}" >&2
    install -m 0644 "${output}/blueprint.json" \
      "${REPO_ROOT}/Examples/S3/architecture/${posture}/blueprint.json"
    install -m 0644 "${output}/awsdac.yaml" \
      "${REPO_ROOT}/Examples/S3/architecture/${posture}/awsdac.yaml"
    install -m 0644 "${output}/architecture.png" \
      "${REPO_ROOT}/Examples/S3/architecture/${posture}/architecture.png"
  else
    for artifact in blueprint.json awsdac.yaml; do
      cmp --silent \
        "${output}/${artifact}" \
        "${REPO_ROOT}/Examples/S3/architecture/${posture}/${artifact}" || {
        printf '[error] generated artifact drift: %s/%s\n' "${posture}" "${artifact}" >&2
        exit 1
      }
    done
    python3 "${source_copy}/scripts/architecture/model_pipeline.py" compare-png \
      "${REPO_ROOT}/Examples/S3/architecture/${posture}/architecture.png" \
      "${output}/architecture.png"
  fi
done

if [[ -n ${ARCHITECTURE_ARTIFACT_DIR:-} ]]; then
  [[ ${ARCHITECTURE_ARTIFACT_DIR} == /* ]] || {
    printf '[error] ARCHITECTURE_ARTIFACT_DIR must be absolute\n' >&2
    exit 1
  }
  [[ ! -e ${ARCHITECTURE_ARTIFACT_DIR} ]] || {
    printf '[error] artifact directory already exists: %s\n' "${ARCHITECTURE_ARTIFACT_DIR}" >&2
    exit 1
  }
  mkdir -p "${ARCHITECTURE_ARTIFACT_DIR}/evidence" "${ARCHITECTURE_ARTIFACT_DIR}/generated"
  cp -R "${work_dir}/evidence/." "${ARCHITECTURE_ARTIFACT_DIR}/evidence/"
  for posture in current-state target-state; do
    mkdir -p "${ARCHITECTURE_ARTIFACT_DIR}/generated/${posture}"
    for artifact in blueprint.json awsdac.yaml architecture.png awsdac.log; do
      install -m 0644 \
        "${source_copy}/Examples/S3/architecture/${posture}/${artifact}" \
        "${ARCHITECTURE_ARTIFACT_DIR}/generated/${posture}/${artifact}"
    done
  done
  printf '[debug] copied sanitized CI artifacts to %s\n' \
    "${ARCHITECTURE_ARTIFACT_DIR}" >&2
fi

printf '[debug] isolated architecture integration passed without errors or warnings\n' >&2
