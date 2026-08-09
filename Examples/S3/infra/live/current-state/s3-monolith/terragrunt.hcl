# The monolith — 04 §4.6 and §4.9
#
# "One data store holding three classifications is the single highest-leverage
# finding in this whole guide."
#
# Public marketing assets, unscanned user-generated content, and regulated PII
# exports share one bucket, one policy, and one blast radius. Everything below
# is downstream of that one decision.
#
# Findings open here: F-01, F-02, F-03, F-11, ENC-1, ENC-2, ENC-5, ENC-6, LOG-1

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/s3-data-bucket"
}

dependency "kms" {
  config_path = "../kms"
  mock_outputs = {
    key_arn = null
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "logging" {
  config_path = "../logging"
  mock_outputs = {
    access_log_bucket_name = null
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  purpose = "monolith"

  # This value IS the finding. 04 §4.6: "Data: mixed (public assets + PII +
  # UGC) · Classification: worst-case regulated".
  classification = "mixed-worst-case-regulated"

  # --- F-02 · the backstop is off -----------------------------------------
  block_public_access = false

  # --- F-01 · anonymous GetObject on a bucket holding PII ------------------
  allow_anonymous_read = true

  # --- F-03 · and the index is public too ---------------------------------
  allow_anonymous_list = true
  deny_anonymous_list  = false

  # --- 04 §4.11 · the legacy ACL code path is still live -------------------
  # BPA would override ACLs; BucketOwnerEnforced would REMOVE them. Neither is
  # in place, which is the third independent way the boundary fails (04 §4.8).
  object_ownership = "ObjectWriter"

  # --- F-11 · no versioning, so an overwrite or delete is terminal ---------
  versioning_enabled  = false
  object_lock_enabled = false

  # --- ENC-2 / ENC-5 / ENC-6 ----------------------------------------------
  kms_key_arn            = dependency.kms.outputs.key_arn # null → SSE-S3
  enforce_sse_kms_writes = false
  deny_sse_c             = false

  # --- ENC-1 · protection depends on every caller behaving -----------------
  deny_insecure_transport = false
  minimum_tls_version     = null

  # --- LOG-1 · access logging does exist, but see logging/ ------------------
  access_log_bucket = dependency.logging.outputs.access_log_bucket_name

  # --- P-01 · no retention has ever been defined for the avatar prefix -----
  lifecycle_rules = []

  # Synthetic fixtures so the exfiltration is real rather than described.
  # 04 §4.9 prefixes: /public/, /avatars/, /exports/
  seed_objects = {
    "public/marketing/spring-campaign.txt" = "Public marketing asset. No sensitivity."
    "avatars/user-1042.txt"                = "SYNTHETIC avatar placeholder — unscanned UGC (F-12)."
    "exports/customer_12345.csv"           = "SYNTHETIC — id,name,email,postal\n12345,Test Person,test@example.invalid,1 Test St"
    "exports/customer_12346.csv"           = "SYNTHETIC — id,name,email,postal\n12346,Other Person,other@example.invalid,2 Test St"
    "exports/manifest.json"                = "{\"files\":[\"customer_12345.csv\",\"customer_12346.csv\"],\"checked_at\":\"2026-08-09T00:00:00Z\"}"
  }
}
