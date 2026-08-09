# Account C — bucket: customer-exports (04 §4.10)
#
# "CMK · Object Lock · versioned". The crown jewels, alone in their own bucket
# with their own key and their own reader.
#
# Closes: F-01, F-02, F-03, F-11, ENC-1, ENC-2, ENC-5, ENC-6, LOG-1
# Structurally supports the F-07 fix (versioning enables pinned versionId reads)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/s3-data-bucket"
}

dependency "kms" {
  config_path = "../kms-regulated"
  mock_outputs = {
    key_arn = "arn:aws:kms:us-east-1:000000000000:key/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "logging" {
  config_path = "../logging"
  mock_outputs = {
    access_log_bucket_name = "mock-logs"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    analytics_reader_role_arn = "arn:aws:iam::000000000000:role/mock-reader"
    partner_role_arn          = "arn:aws:iam::000000000000:role/mock-partner"
    human_role_arns           = { readonly = "arn:aws:iam::000000000000:role/mock-ro" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  purpose        = "customer-exports"
  classification = "regulated-pii"

  # --- F-01 / F-02 / F-03 -------------------------------------------------
  block_public_access  = true
  allow_anonymous_read = false
  allow_anonymous_list = false
  deny_anonymous_list  = true

  # 04 §4.11 — BucketOwnerEnforced RETIRES the legacy ACL code path rather
  # than merely overriding it. Those are different security postures.
  object_ownership = "BucketOwnerEnforced"

  # --- F-11 · versioning first (13 §13.5 step 1) --------------------------
  versioning_enabled = true

  # --- F-11 / ENC-6 · Object Lock -----------------------------------------
  # 13 §13.3 says resolve the Compliance-vs-erasure conflict BEFORE choosing.
  # The decision recorded here: GOVERNANCE, not COMPLIANCE.
  #
  # Why: Compliance mode cannot be overridden by anyone including root, which
  # would make GDPR Art. 17 erasure (P-02) impossible for the retention period.
  # BAK-2 argues for Compliance; P-02 argues for verified erasure; neither is
  # wrong. Governance mode keeps the ransomware protection while leaving the
  # PrivacyOps role a documented, logged override path via
  # s3:BypassGovernanceRetention.
  #
  # Revisit this if a legal retention requirement ever overrides erasure rights
  # for this data class — then Compliance mode becomes correct.
  object_lock_enabled        = true
  object_lock_mode           = "GOVERNANCE"
  object_lock_retention_days = 30

  # --- ENC-2 / ENC-5 / ENC-6 ----------------------------------------------
  kms_key_arn            = dependency.kms.outputs.key_arn
  enforce_sse_kms_writes = true # deny writes lacking aws:kms AND under any other key
  deny_sse_c             = true # the one-command ransomware primitive
  bucket_key_enabled     = true # cost optimisation, not a security downgrade

  # --- ENC-1 --------------------------------------------------------------
  deny_insecure_transport = true
  minimum_tls_version     = "1.2"

  # --- LOG-1 --------------------------------------------------------------
  access_log_bucket = dependency.logging.outputs.access_log_bucket_name

  # --- Named grants (F-19: need-to-know, not role-wide) -------------------
  read_principal_arns = [
    dependency.iam.outputs.analytics_reader_role_arn,
    dependency.iam.outputs.human_role_arns["readonly"],
  ]
  read_prefixes = ["exports/"]

  # F-14 · the partner writes to exactly one prefix and can read nothing.
  write_principal_arns = [dependency.iam.outputs.partner_role_arn]
  write_prefixes       = ["partner/"]

  # --- P-01 / P-02 / 13 §13.2 Level D -------------------------------------
  # 90 noncurrent days = the forensic window, chosen deliberately. Note the
  # P-02 sequencing warning: enabling versioning makes erasure HARDER unless a
  # version-aware deletion runbook exists first. See scripts/erasure-runbook.md.
  lifecycle_rules = [
    {
      id                                 = "exports-forensic-window"
      prefix                             = "exports/"
      noncurrent_version_expiration_days = 90
    },
    {
      id                                 = "partner-inbound-retention"
      prefix                             = "partner/"
      expiration_days                    = 30
      noncurrent_version_expiration_days = 90
    },
  ]

  seed_objects = {
    "exports/manifest.json" = "{\"files\":[\"customer_12345.csv\"],\"checked_at\":\"2026-08-09T00:00:00Z\"}"
  }
}
