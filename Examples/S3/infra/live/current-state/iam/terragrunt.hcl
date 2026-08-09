# The identity plane as it exists — session finding S6
#
# "AWS is root-user-only — no IAM users, roles, or groups beyond defaults."
# What roles do exist grew organically to unblock deploys and were never shrunk
# back (12 §12.8, the most common origin of over-permissioned service accounts
# anywhere).
#
# Findings open here: F-09, F-13 (blast radius), F-14, F-15, F-18, F-19

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/iam-estate"
}

dependency "s3" {
  config_path = "../s3-monolith"
  mock_outputs = {
    bucket_arn = "arn:aws:s3:::mock-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  managed_bucket_arns = [dependency.s3.outputs.bucket_arn]

  # --- F-09 · "The finding is that we do not know." -----------------------
  # Written down, an unverified deploy role looks like this: it can rewrite the
  # bucket policy of EVERY bucket in the account, and the change arrives
  # through the legitimate path looking like a normal deploy.
  cicd_wildcard_resource = true

  # --- F-17 · the OIDC trust is scoped to the repo but not the branch ------
  # A fork's PR workflow can therefore reach the deploy role.
  cicd_oidc_subject = "repo:meridian-retail/s3-platform:*"

  # --- F-02 / F-17 · no SCP backstop --------------------------------------
  scp_backstop_as_inline_deny = false

  # --- F-13 · the compute role carries kms:Decrypt on everything ----------
  # This is what turns SSRF from "read some objects" into "read the estate".
  compute_role_can_decrypt = true
  kms_key_arns_wildcard    = true

  # --- F-14 · the confused deputy, both halves ----------------------------
  create_partner_role            = true
  partner_external_id            = null # no sts:ExternalId
  partner_require_source_account = false
  partner_cross_prefix_access    = true # Resource = bucket/*, so /exports/ is readable

  # --- F-18 · the agent's tool belt IS its blast radius -------------------
  create_agent_role = true
  agent_can_write   = true
  agent_can_decrypt = true

  # --- F-19 / S6 · no separation of duties --------------------------------
  separate_duties = false

  # --- F-15 · a long-lived access key that outlives employment ------------
  create_static_access_keys = true
}
