#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"

"${SCRIPT_DIR}/preflight.sh" >/dev/null

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_EC2_METADATA_DISABLED=true

failures=0

pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'GAP   %s\n' "$1"; }
fail() {
  printf 'FAIL  %s\n' "$1" >&2
  failures=$((failures + 1))
}

aws_local() {
  aws --endpoint-url "${FLOCI_ENDPOINT}" "$@"
}

check_jq() {
  local description="$1"
  local filter="$2"
  local payload="$3"
  if jq -e "${filter}" >/dev/null <<<"${payload}"; then
    pass "${description}"
  else
    fail "${description}"
  fi
}

echo "==> Current-state evidence"
current_policy="$(aws_local s3api get-bucket-policy --bucket meridian-cs-monolith --query Policy --output text)"
check_jq "F-01 anonymous object-read Allow is present" \
  '.Statement | any(.Sid == "F01_AnonymousGetObject" and .Effect == "Allow")' "${current_policy}"
check_jq "F-03 anonymous bucket-list Allow is present" \
  '.Statement | any(.Sid == "F03_AnonymousListBucket" and .Effect == "Allow")' "${current_policy}"

current_encryption="$(aws_local s3api get-bucket-encryption --bucket meridian-cs-monolith)"
check_jq "Current monolith uses SSE-S3, not a customer-managed KMS key" \
  '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm == "AES256"' \
  "${current_encryption}"

current_selectors="$(aws_local cloudtrail get-event-selectors --trail-name meridian-cs-trail)"
check_jq "LOG-1 is reproduced: current trail has no S3 object data events" \
  '([.EventSelectors[].DataResources[]?] | length) == 0' "${current_selectors}"

if aws --endpoint-url "${FLOCI_ENDPOINT}" --no-sign-request s3api list-objects-v2 \
  --bucket meridian-cs-monolith >/dev/null 2>&1; then
  pass "Unsigned enumeration succeeds against the intentionally vulnerable bucket"
else
  fail "Unsigned enumeration should succeed against the intentionally vulnerable bucket"
fi

echo "==> Target-state evidence"
for bucket in \
  meridian-ts-public-assets \
  meridian-ts-customer-exports \
  meridian-ts-user-content \
  meridian-ts-ugc-quarantine; do
  bpa="$(aws_local s3api get-public-access-block --bucket "${bucket}")"
  check_jq "${bucket}: all four Block Public Access controls are enabled" \
    '.PublicAccessBlockConfiguration | [.BlockPublicAcls, .IgnorePublicAcls, .BlockPublicPolicy, .RestrictPublicBuckets] | all' \
    "${bpa}"

  versioning="$(aws_local s3api get-bucket-versioning --bucket "${bucket}")"
  check_jq "${bucket}: versioning is enabled" '.Status == "Enabled"' "${versioning}"

  ownership="$(aws_local s3api get-bucket-ownership-controls --bucket "${bucket}")"
  check_jq "${bucket}: legacy ACL evaluation is retired" \
    '.OwnershipControls.Rules[0].ObjectOwnership == "BucketOwnerEnforced"' "${ownership}"
done

for bucket in meridian-ts-customer-exports meridian-ts-user-content meridian-ts-ugc-quarantine; do
  encryption="$(aws_local s3api get-bucket-encryption --bucket "${bucket}")"
  check_jq "${bucket}: default encryption uses a named KMS key" \
    '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault | .SSEAlgorithm == "aws:kms" and (.KMSMasterKeyID | length > 0)' \
    "${encryption}"

  policy="$(aws_local s3api get-bucket-policy --bucket "${bucket}" --query Policy --output text)"
  check_jq "${bucket}: policy denies non-KMS writes, unsanctioned keys, SSE-C, and insecure transport" \
    '([.Statement[].Sid] | contains(["ENC1_DenyInsecureTransport", "ENC5_DenyWritesWithoutKmsSse", "ENC5_DenyWritesUnderUnsanctionedKey", "ENC6_DenySseCustomerProvidedKeys"]))' \
    "${policy}"
done

target_selectors="$(aws_local cloudtrail get-event-selectors --trail-name meridian-ts-trail)"
check_jq "Target trail records S3 object data events for all four data buckets" \
  '([.EventSelectors[].DataResources[]? | select(.Type == "AWS::S3::Object") | .Values[]] | length) == 4' \
  "${target_selectors}"

rules="$(aws_local events list-rules)"
check_jq "Target posture has EventBridge detection rules" \
  '([.Rules[] | select(.Name | startswith("meridian-ts-"))] | length) >= 4' "${rules}"

compute_output="$(cd "${INFRA_DIR}/live/target-state/compute" && terragrunt output -json 2>/dev/null)"
check_jq "Target compute configuration requires IMDSv2 and limits the metadata hop count" \
  '.imds_posture.value == "http_tokens=required hop_limit=1" and (.posture_summary.value | length) == 0' \
  "${compute_output}"

instances="$(aws_local ec2 describe-instances)"
if jq -e 'any(.Reservations[].Instances[]; (.Tags // [] | any(.Key == "Environment" and .Value == "target-state")) and .MetadataOptions.HttpTokens == "required")' \
  >/dev/null <<<"${instances}"; then
  pass "Floci reports IMDSv2 enforcement on the target instance"
elif jq -e 'any(.Reservations[].Instances[]; .Tags // [] | any(.Key == "Environment" and .Value == "target-state"))' \
  >/dev/null <<<"${instances}"; then
  warn "Floci stores the target instance but does not report IMDSv2 faithfully; verify on AWS"
else
  warn "GAP-FLOCI-EC2: clean Floci terminates EC2 during provider creation; the reviewed IMDS contract is not runtime evidence"
fi

# Floci 1.6.0 persists S3 policies but does not evaluate them in the unsigned
# data plane. This probe documents that known emulator gap without pretending
# the target policy failed to render.
if aws --endpoint-url "${FLOCI_ENDPOINT}" --no-sign-request s3api list-objects-v2 \
  --bucket meridian-ts-customer-exports >/dev/null 2>&1; then
  warn "Floci accepts unsigned target-bucket reads; policy enforcement must be tested on AWS or a policy-aware emulator"
else
  pass "Unsigned target-bucket enumeration is denied"
fi

if ((failures > 0)); then
  echo "Verification failed: ${failures} check(s) did not match the model." >&2
  exit 1
fi

echo "Verification passed. GAP lines are explicit emulator limitations, not control assertions."
