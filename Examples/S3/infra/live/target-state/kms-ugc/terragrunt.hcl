# The UGC-tier CMK
#
# A separate key from the regulated tier, for exactly the reason 13 §13.4
# gives: one compromise or revocation should not force re-keying everything.
# The UGC bucket is the one an attacker with a free account can write to
# (A-2), so its key is the one most likely to need emergency rotation.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/kms-cmk"
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    app_compute_role_arn     = "arn:aws:iam::000000000000:role/mock-compute"
    analytics_agent_role_arn = "arn:aws:iam::000000000000:role/mock-agent"
    human_role_arns          = { incidentresponder = "arn:aws:iam::000000000000:role/mock-ir" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  tier       = "user-content"
  create_cmk = true

  delegate_to_account_root = false
  decrypt_principal_arns = [
    dependency.iam.outputs.app_compute_role_arn,
    dependency.iam.outputs.analytics_agent_role_arn,
  ]

  require_via_service    = true
  require_source_account = true

  deny_key_lifecycle_ops = true
  deny_grant_operations  = true
  break_glass_arns       = [dependency.iam.outputs.human_role_arns["incidentresponder"]]

  enable_key_rotation     = true
  rotation_period_in_days = 180
}
