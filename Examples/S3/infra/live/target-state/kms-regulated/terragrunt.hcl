# The regulated-tier CMK — the second access-control plane, hardened
#
# 13 §13.7's central observation: almost every row in the KMS exploit→control
# map is a KEY-POLICY CONDITION or an SCP, not an S3 setting. "A team that
# 'hardened S3' and never opened the key policy has bolted one door and left
# the other open."
#
# Closes ENC-2 (a CMK exists at all), ENC-3 (named principals, no :root),
# ENC-4 (ViaService + SourceAccount + encryption context), ENC-7 and ENC-8.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/kms-cmk"
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    all_principal_arns        = ["arn:aws:iam::000000000000:role/mock"]
    analytics_reader_role_arn = "arn:aws:iam::000000000000:role/mock-reader"
    analytics_agent_role_arn  = "arn:aws:iam::000000000000:role/mock-agent"
    human_role_arns = {
      incidentresponder = "arn:aws:iam::000000000000:role/mock-ir"
      readonly          = "arn:aws:iam::000000000000:role/mock-readonly"
      privacyops        = "arn:aws:iam::000000000000:role/mock-privacy"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  # 13 §13.4 — "separate CMK per sensitivity tier is to the key plane what
  # separate buckets is to the storage plane: it turns one catastrophic blast
  # radius into three contained ones."
  tier       = "customer-exports"
  create_cmk = true

  # --- ENC-3 · named principals only, no :root delegation -----------------
  delegate_to_account_root = false
  decrypt_principal_arns = [
    dependency.iam.outputs.analytics_reader_role_arn,
    dependency.iam.outputs.analytics_agent_role_arn,
    dependency.iam.outputs.human_role_arns["readonly"],
    dependency.iam.outputs.human_role_arns["privacyops"],
  ]

  # F-14 · no KMS grant to the partner. Their objects go to a prefix they can
  # write and never read; they have no business decrypting anything.
  cross_account_principal_arns = []

  # --- ENC-4 · the two conditions plus the encryption context -------------
  require_via_service    = true
  require_source_account = true
  required_encryption_context = {
    # Binds this key to one prefix. Without it, one key decrypts everything it
    # can reach rather than only its intended scope.
    "aws:s3:arn" = "exports"
  }

  # --- ENC-7 / ENC-8 · lifecycle and persistence --------------------------
  deny_key_lifecycle_ops = true
  deny_grant_operations  = true
  break_glass_arns       = [dependency.iam.outputs.human_role_arns["incidentresponder"]]

  # --- 13 §13.4 Level C ---------------------------------------------------
  # Rotation is configurable 90..2560 days and does NOT change the key ARN or
  # require re-encrypting existing data. It is also commonly overrated: it
  # limits the useful life of a STOLEN key and does nothing against an attacker
  # holding valid IAM permissions. Scoping (above) is the load-bearing control.
  enable_key_rotation     = true
  rotation_period_in_days = 365
  deletion_window_in_days = 30
}
