#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INFRA_DIR="${REPO_ROOT}/Examples/S3/infra"
PIPELINE="${SCRIPT_DIR}/model_pipeline.py"
FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://127.0.0.1:4566}"

debug() { printf '[debug] %s\n' "$*" >&2; }
die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || die "usage: $0 <current-state|target-state> <evidence-dir>"
posture="$1"
evidence_dir="$2"
[[ ${posture} == current-state || ${posture} == target-state ]] ||
  die "posture must be current-state or target-state"
[[ ${evidence_dir} == /* ]] || die "evidence-dir must be an absolute path"
[[ ! -e ${evidence_dir} ]] || die "evidence-dir already exists: ${evidence_dir}"

for command in aws curl jq python3 rg terragrunt tofu trufflehog; do
  command -v "${command}" >/dev/null || die "required command not found: ${command}"
done

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/meridian-architecture.XXXXXX")"
cleanup() {
  [[ -d ${temp_dir} && ${temp_dir} == "${TMPDIR:-/tmp}/meridian-architecture."* ]] ||
    die "refusing to remove unexpected temporary path: ${temp_dir}"
  rm -rf -- "${temp_dir}"
}
trap cleanup EXIT

mkdir -p "${evidence_dir}/logs" "${evidence_dir}/plans"

sanitize_and_check_log() {
  local raw_log="$1"
  local safe_log="$2"
  python3 "${PIPELINE}" sanitize-log "${raw_log}" "${safe_log}"
  if rg --line-number '(^|[[:space:]])(WARN|WARNING|Warning)([[:space:]:]|$)' "${safe_log}"; then
    die "warning detected in ${safe_log}"
  fi
  "${REPO_ROOT}/scripts/ci/run-trufflehog.sh" filesystem "${safe_log}"
}

run_logged() {
  local log_name="$1"
  shift
  local raw_log="${temp_dir}/${log_name}.raw.log"
  local safe_log="${evidence_dir}/logs/${log_name}.log"
  debug "running: $*"
  if "$@" >"${raw_log}" 2>&1; then
    sanitize_and_check_log "${raw_log}" "${safe_log}"
    sed -n '1,200p' "${safe_log}" >&2
  else
    local status=$?
    python3 "${PIPELINE}" sanitize-log "${raw_log}" "${safe_log}"
    sed -n '1,240p' "${safe_log}" >&2
    die "command failed with status ${status}: $*"
  fi
}

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_EC2_METADATA_DISABLED=true
export AWS_ENDPOINT_URL="${FLOCI_ENDPOINT}"

debug "checking Floci health at ${FLOCI_ENDPOINT}"
curl --fail --silent --show-error "${FLOCI_ENDPOINT}/_floci/health" >/dev/null
run_logged preflight "${INFRA_DIR}/scripts/preflight.sh"

raw_plans="${temp_dir}/plans"
raw_json="${temp_dir}/json"
mkdir -p "${raw_plans}" "${raw_json}"
run_logged terragrunt-plan \
  terragrunt run --all --fail-fast --non-interactive --no-color --log-level debug \
  --working-dir "${INFRA_DIR}/live/${posture}" \
  --out-dir "${raw_plans}" --json-out-dir "${raw_json}" -- \
  plan -input=false -lock=false

debug "sanitizing every plan before it leaves private temporary storage"
plan_list="${temp_dir}/plan-files.txt"
find "${raw_json}" -type f -name tfplan.json -print | sort >"${plan_list}"
while IFS= read -r source; do
  source_dir="$(dirname "${source}")"
  unit="$(basename "${source_dir}")"
  destination="${evidence_dir}/plans/${unit}/tfplan.json"
  destination_dir="$(dirname "${destination}")"
  mkdir -p "${destination_dir}"
  python3 "${PIPELINE}" sanitize-plan "${source}" "${destination}"
  "${REPO_ROOT}/scripts/ci/run-trufflehog.sh" filesystem "${destination}"
done <"${plan_list}"

debug "capturing the Terragrunt dependency graph"
dag_raw_log="${temp_dir}/terragrunt-dag.raw.log"
if terragrunt dag graph --no-color --log-level debug \
  --working-dir "${INFRA_DIR}/live/${posture}" \
  >"${evidence_dir}/dag.dot" 2>"${dag_raw_log}"; then
  sanitize_and_check_log "${dag_raw_log}" "${evidence_dir}/logs/terragrunt-dag.log"
else
  status=$?
  python3 "${PIPELINE}" sanitize-log "${dag_raw_log}" "${evidence_dir}/logs/terragrunt-dag.log"
  sed -n '1,240p' "${evidence_dir}/logs/terragrunt-dag.log" >&2
  die "Terragrunt DAG failed with status ${status}"
fi
rg --quiet '^digraph' "${evidence_dir}/dag.dot" || die "Terragrunt DAG is not DOT"

aws_json() {
  local output="$1"
  shift
  debug "inventory query: aws $*"
  aws "$@" --output json >"${temp_dir}/${output}"
}
aws_json s3.json s3api list-buckets
aws_json roles.json iam list-roles
aws_json users.json iam list-users
aws_json aliases.json kms list-aliases
aws_json trails.json cloudtrail describe-trails
aws_json rules.json events list-rules
aws_json topics.json sns list-topics
aws_json instances.json ec2 describe-instances

if [[ ${posture} == current-state ]]; then
  prefix="meridian-cs-"
else
  prefix="meridian-ts-"
fi
jq -n \
  --arg endpoint "${FLOCI_ENDPOINT}" \
  --arg prefix "${prefix}" \
  --slurpfile s3 "${temp_dir}/s3.json" \
  --slurpfile roles "${temp_dir}/roles.json" \
  --slurpfile users "${temp_dir}/users.json" \
  --slurpfile aliases "${temp_dir}/aliases.json" \
  --slurpfile trails "${temp_dir}/trails.json" \
  --slurpfile rules "${temp_dir}/rules.json" \
  --slurpfile topics "${temp_dir}/topics.json" \
  --slurpfile instances "${temp_dir}/instances.json" \
  '{
    endpoint: $endpoint,
    scope_prefix: $prefix,
    buckets: [$s3[0].Buckets[] | .Name | select(startswith($prefix))] | sort,
    roles: [$roles[0].Roles[] | select(.RoleName | startswith($prefix)) | {name: .RoleName, arn: .Arn}] | sort_by(.name),
    users: [$users[0].Users[] | select(.UserName | startswith($prefix)) | {name: .UserName, arn: .Arn}] | sort_by(.name),
    kms_aliases: [$aliases[0].Aliases[] | select(.AliasName | startswith("alias/" + $prefix)) | {name: .AliasName, target_key_id: .TargetKeyId}] | sort_by(.name),
    trails: [$trails[0].trailList[] | select(.Name | startswith($prefix)) | {name: .Name, arn: .TrailARN, bucket: .S3BucketName}] | sort_by(.name),
    event_rules: [$rules[0].Rules[] | select(.Name | startswith($prefix)) | {name: .Name, arn: .Arn, state: .State}] | sort_by(.name),
    topics: [$topics[0].Topics[] | select(.TopicArn | contains($prefix)) | .TopicArn] | sort,
    instances: [$instances[0].Reservations[].Instances[]? | select(any(.Tags[]?; .Key == "Name" and (.Value | startswith($prefix)))) | {id: .InstanceId, state: .State.Name, metadata_options: .MetadataOptions, tags: .Tags}] | sort_by(.id)
  }' >"${evidence_dir}/inventory.json"

terragrunt_version_output="$(terragrunt --version)"
terragrunt_version="${terragrunt_version_output##* }"
tofu_version_json="$(tofu version -json)"
tofu_version="$(jq -er .terraform_version <<<"${tofu_version_json}")"
floci_version_output="$(floci version)"
floci_version="$(awk '/Floci CLI/{print $3}' <<<"${floci_version_output}")"
aws_version_output="$(aws --version 2>&1)"
aws_version="$(sed -E 's#aws-cli/([^ ]+).*#\1#' <<<"${aws_version_output}")"

jq -n \
  --arg terragrunt "${terragrunt_version}" \
  --arg tofu "${tofu_version}" \
  --arg floci_cli "${floci_version}" \
  --arg aws_cli "${aws_version}" \
  '{terragrunt: $terragrunt, opentofu: $tofu, floci_cli: $floci_cli, aws_cli: $aws_cli}' \
  >"${evidence_dir}/versions.json"
python3 "${PIPELINE}" manifest \
  --evidence-dir "${evidence_dir}" --posture "${posture}" \
  --versions "${evidence_dir}/versions.json"
debug "sanitized architecture evidence captured at ${evidence_dir}"
