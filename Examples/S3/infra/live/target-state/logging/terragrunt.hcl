# LOG-1 · closed
#
# Data events on, so an object read is attributable to an identity. This is the
# control that makes F-19 (insider bulk access) detectable at all, and it is
# one of the two cheapest links to break in the F-20 attack chain.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/logging-trail"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  name_prefix = "meridian-${local.env_vars.locals.short}"
}

inputs = {
  # LOG-1's actual fix.
  enable_data_events = true
  data_event_bucket_arns = [
    "arn:aws:s3:::${local.name_prefix}-public-assets",
    "arn:aws:s3:::${local.name_prefix}-user-content",
    "arn:aws:s3:::${local.name_prefix}-customer-exports",
    "arn:aws:s3:::${local.name_prefix}-ugc-quarantine",
  ]

  create_access_log_bucket   = true
  enable_log_file_validation = true

  # 13 §13.2 Level D — 90 days is the forensic window. The number is written
  # down here on purpose: a cost-optimisation lifecycle rule authored by
  # someone who was not in the threat-modeling session is exactly how incident
  # response evidence gets silently destroyed.
  log_retention_days = 90
}
