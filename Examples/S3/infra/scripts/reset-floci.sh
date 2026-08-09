#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# reset-floci.sh — wipe every Meridian lab resource from the local emulator.
#
# Use this when Terragrunt state and Floci have drifted apart (for example
# after deleting .tfstate/ by hand, or after a partial apply). `terragrunt
# destroy` is the normal path; this is the sledgehammer.
#
# Only touches resources whose name starts with "meridian-".
# ---------------------------------------------------------------------------
set -uo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ENDPOINT_URL="${FLOCI_ENDPOINT:-http://localhost:4566}"

PREFIX="meridian-"
INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Resetting Floci resources with prefix '${PREFIX}' at ${AWS_ENDPOINT_URL}"

# --- S3 --------------------------------------------------------------------
for b in $(aws s3api list-buckets --query "Buckets[?starts_with(Name,'${PREFIX}')].Name" --output text); do
  echo "    s3: removing ${b}"
  # Delete every version and delete marker before the bucket itself.
  aws s3api list-object-versions --bucket "${b}" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null |
    python3 -c 'import sys,json;d=json.load(sys.stdin);print(json.dumps(d) if d.get("Objects") else "")' |
    {
      read -r payload
      [[ -n ${payload} ]] && aws s3api delete-objects --bucket "${b}" --delete "${payload}" >/dev/null 2>&1
    }
  aws s3api list-object-versions --bucket "${b}" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null |
    python3 -c 'import sys,json;d=json.load(sys.stdin);print(json.dumps(d) if d.get("Objects") else "")' |
    {
      read -r payload
      [[ -n ${payload} ]] && aws s3api delete-objects --bucket "${b}" --delete "${payload}" >/dev/null 2>&1
    }
  aws s3 rm "s3://${b}" --recursive >/dev/null 2>&1
  aws s3api delete-bucket --bucket "${b}" >/dev/null 2>&1 || echo "        (could not delete ${b} — may hold locked objects)"
done

# --- IAM -------------------------------------------------------------------
for r in $(aws iam list-roles --query "Roles[?starts_with(RoleName,'${PREFIX}')].RoleName" --output text); do
  echo "    iam: removing role ${r}"
  for p in $(aws iam list-role-policies --role-name "${r}" --query 'PolicyNames[]' --output text 2>/dev/null); do
    aws iam delete-role-policy --role-name "${r}" --policy-name "${p}" >/dev/null 2>&1
  done
  for ip in $(aws iam list-instance-profiles-for-role --role-name "${r}" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null); do
    aws iam remove-role-from-instance-profile --instance-profile-name "${ip}" --role-name "${r}" >/dev/null 2>&1
  done
  aws iam delete-role --role-name "${r}" >/dev/null 2>&1
done

for ip in $(aws iam list-instance-profiles --query "InstanceProfiles[?starts_with(InstanceProfileName,'${PREFIX}')].InstanceProfileName" --output text); do
  echo "    iam: removing instance profile ${ip}"
  aws iam delete-instance-profile --instance-profile-name "${ip}" >/dev/null 2>&1
done

for u in $(aws iam list-users --query "Users[?starts_with(UserName,'${PREFIX}')].UserName" --output text); do
  echo "    iam: removing user ${u}"
  for k in $(aws iam list-access-keys --user-name "${u}" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
    aws iam delete-access-key --user-name "${u}" --access-key-id "${k}" >/dev/null 2>&1
  done
  for p in $(aws iam list-user-policies --user-name "${u}" --query 'PolicyNames[]' --output text 2>/dev/null); do
    aws iam delete-user-policy --user-name "${u}" --policy-name "${p}" >/dev/null 2>&1
  done
  aws iam delete-user --user-name "${u}" >/dev/null 2>&1
done

# --- CloudTrail ------------------------------------------------------------
for t in $(aws cloudtrail list-trails --query "Trails[?starts_with(Name,'${PREFIX}')].Name" --output text 2>/dev/null); do
  echo "    cloudtrail: removing ${t}"
  aws cloudtrail delete-trail --name "${t}" >/dev/null 2>&1
done

# --- KMS (schedule deletion — the minimum window is 7 days) ----------------
for k in $(aws kms list-aliases --query "Aliases[?starts_with(AliasName,'alias/${PREFIX}')].AliasName" --output text 2>/dev/null); do
  echo "    kms: removing alias ${k}"
  aws kms delete-alias --alias-name "${k}" >/dev/null 2>&1
done

# --- EventBridge / SNS / Config -------------------------------------------
for r in $(aws events list-rules --query "Rules[?starts_with(Name,'${PREFIX}')].Name" --output text 2>/dev/null); do
  echo "    events: removing rule ${r}"
  ids=$(aws events list-targets-by-rule --rule "${r}" --query 'Targets[].Id' --output text 2>/dev/null)
  if [[ -n ${ids} ]]; then
    read -r -a target_ids <<<"${ids}"
    aws events remove-targets --rule "${r}" --ids "${target_ids[@]}" >/dev/null 2>&1
  fi
  aws events delete-rule --name "${r}" >/dev/null 2>&1
done

for t in $(aws sns list-topics --query "Topics[?contains(TopicArn,'${PREFIX}')].TopicArn" --output text 2>/dev/null); do
  echo "    sns: removing ${t}"
  aws sns delete-topic --topic-arn "${t}" >/dev/null 2>&1
done

for c in $(aws configservice describe-config-rules --query "ConfigRules[?starts_with(ConfigRuleName,'${PREFIX}')].ConfigRuleName" --output text 2>/dev/null); do
  echo "    config: removing rule ${c}"
  aws configservice delete-config-rule --config-rule-name "${c}" >/dev/null 2>&1
done

# --- Terragrunt state ------------------------------------------------------
if [[ ${1:-} == "--state" ]]; then
  echo "    terragrunt: removing local state and caches"
  rm -rf "${INFRA_DIR}/.tfstate"
  find "${INFRA_DIR}/live" -name '.terragrunt-cache' -type d -exec rm -rf {} + 2>/dev/null
fi

echo "==> Done. EC2 instances and CloudFront distributions are left in place;"
echo "    Floci discards them when the container restarts (floci restart)."
