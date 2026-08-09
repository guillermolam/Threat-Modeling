# Account B — the quarantine bucket (04 §4.16 target flow)
#
# F-12's fix is a PIPELINE, not a setting:
#   presigned PUT (5min TTL, 1 object) → quarantine → magic-byte validation
#   → malware scan → decode + re-encode from raw pixels → clean bucket
#
# The re-encode is the step that actually defeats steganography: "passthrough
# serving of original bytes is precisely what preserves a hidden payload."
#
# This unit builds the quarantine landing zone. The scan/re-encode worker
# itself is application code, not infrastructure — see the assumption recorded
# in threat-model/meridian-s3.tc.json.

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

inputs = {
  purpose        = "ugc-quarantine"
  classification = "untrusted-user-content"

  block_public_access  = true
  allow_anonymous_read = false
  allow_anonymous_list = false
  deny_anonymous_list  = true
  object_ownership     = "BucketOwnerEnforced"

  # Versioned so a malicious upload can be retrieved for analysis after the
  # scanner quarantines or deletes it.
  versioning_enabled = true

  kms_key_arn            = dependency.kms.outputs.key_arn
  enforce_sse_kms_writes = true
  deny_sse_c             = true

  deny_insecure_transport = true
  minimum_tls_version     = "1.2"

  access_log_bucket = dependency.logging.outputs.access_log_bucket_name

  # Nothing lingers in quarantine. A file is either promoted to the clean
  # bucket or it is gone — which also bounds the window in which a staged
  # second-stage payload is retrievable.
  lifecycle_rules = [
    {
      id                                 = "quarantine-is-transient"
      prefix                             = ""
      expiration_days                    = 7
      noncurrent_version_expiration_days = 30
    },
  ]
}
