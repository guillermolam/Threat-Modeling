# Account B — bucket: user-content (04 §4.10)
#
# Only re-encoded, scanned bytes land here. Isolating UGC into its own bucket —
# and ideally its own domain — is not just blast-radius hygiene: it "denies the
# attacker the reputational borrowing that motivates the attack" (F-12).
#
# The attack F-12 describes succeeds "precisely because Meridian's domain is
# allow-listed by network defenses that would have blocked an unknown host."
# A separate domain is the control that removes that ingredient. Floci cannot
# model DNS or CDN domains meaningfully, so that half is recorded as an
# assumption rather than built.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/s3-data-bucket"
}

dependency "kms" {
  config_path = "../kms-ugc"
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

dependency "edge" {
  config_path = "../edge"
  mock_outputs = {
    distribution_arn = "arn:aws:cloudfront::000000000000:distribution/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  purpose        = "user-content"
  classification = "public-but-user-supplied"

  block_public_access  = true
  allow_anonymous_read = false
  allow_anonymous_list = false
  deny_anonymous_list  = true
  object_ownership     = "BucketOwnerEnforced"

  versioning_enabled = true

  kms_key_arn            = dependency.kms.outputs.key_arn
  enforce_sse_kms_writes = true
  deny_sse_c             = true

  deny_insecure_transport = true
  minimum_tls_version     = "1.2"

  access_log_bucket = dependency.logging.outputs.access_log_bucket_name

  # 04 §4.7 · the half OAC does not do by itself. Without this condition an
  # attacker skips the CDN — and with it, the CSP headers that are the other
  # half of F-12's serving-side mitigation.
  cloudfront_distribution_arn = dependency.edge.outputs.distribution_arn

  # P-01 · a retention period for the avatar prefix, which had never been
  # defined. The number needs legal review; 365 days is the placeholder the
  # DPO signs off or changes.
  lifecycle_rules = [
    {
      id                                 = "avatar-retention-P01"
      prefix                             = "avatars/"
      expiration_days                    = 365
      noncurrent_version_expiration_days = 90
    },
  ]
}
