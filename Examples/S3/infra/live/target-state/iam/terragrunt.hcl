# The identity plane, derived — 12 §12.5
#
# Every role here traces to a risk-register owner or a DFD actor. None is
# invented generically (12 §12.2). Access tier scales with financial exposure:
# higher exposure → more restricted, more monitored, more time-boxed.
#
# This unit deliberately has NO dependency on the buckets. Bucket ARNs are
# computed from the naming convention instead, which breaks what would
# otherwise be a cycle (buckets need the CMK, the CMK needs named principals,
# the principals need the buckets) and lets the DAG run iam → kms → s3.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/iam-estate"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  name_prefix = "meridian-${local.env_vars.locals.short}"

  # 04 §4.10 — three buckets, one per classification.
  bucket_purposes = ["public-assets", "user-content", "customer-exports", "ugc-quarantine"]
}

inputs = {
  managed_bucket_arns = [for b in local.bucket_purposes : "arn:aws:s3:::${local.name_prefix}-${b}"]

  # --- F-09 · replaced with the scoped S3-CustomerData-CICD-Deploy row -----
  # "The fix isn't 'verify the wildcard', it's 'replace it with this row'."
  cicd_wildcard_resource = false

  # --- F-17 · OIDC trust scoped to repository AND branch ------------------
  cicd_oidc_subject = "repo:meridian-retail/s3-platform:ref:refs/heads/main"

  # --- F-02 / F-17 · the backstop -----------------------------------------
  # In real AWS this is an SCP at 04 §4.14 layer 1, above anything a
  # compromised deploy role at layer 4 can reach. Floci has no Organizations,
  # so it is an inline Deny here — weaker, and flagged as such in the README.
  scp_backstop_as_inline_deny = true

  # --- F-13 · "remove kms:Decrypt if unused" ------------------------------
  # The compute tier serves public assets. It has no business decrypting
  # regulated data, so stealing its credentials buys the attacker much less.
  compute_role_can_decrypt = false
  compute_read_prefix      = "public/"

  # --- F-14 · both halves of the confused deputy closed -------------------
  create_partner_role            = true
  partner_external_id            = "meridian-partner-4f2c9a1e-DO-NOT-REUSE"
  partner_require_source_account = true
  partner_cross_prefix_access    = false # write-only, single prefix, no read
  partner_prefix                 = "partner/"

  # --- F-18 · Least Agency ------------------------------------------------
  # Read is autonomous; write / delete / decrypt is gated. IAM can only enforce
  # the removal half — the human-in-the-loop gate is an application control and
  # is carried as an assumption in the threat model, not as a resource here.
  create_agent_role = true
  agent_can_write   = false
  agent_can_decrypt = false

  # --- F-19 · separation of duties ----------------------------------------
  # Five roles from the 12 §12.5 table. The subtle one is SecurityAudit: it can
  # see the CONFIGURATION but not the DATA, which is what lets someone verify
  # the bucket policy without becoming another identity whose compromise means
  # a breach.
  separate_duties = true

  # --- F-15 · no long-lived credentials at all ----------------------------
  # Federation collapses actor A-8 (departed employee) almost entirely.
  create_static_access_keys = false
}
