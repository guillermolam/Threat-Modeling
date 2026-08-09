# LOG-1 · No object-level audit trail
#
# The trap this unit reproduces: CloudTrail IS enabled. The console says so.
# But management events record changes TO the bucket, and only data events
# record access TO objects — so an attacker who reads every customer record
# leaves no trace distinguishable from ordinary traffic.
#
# LOG-1 is the force multiplier that converts every other finding here from a
# detectable incident into an undetectable one.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/logging-trail"
}

inputs = {
  # LOG-1 in one line.
  enable_data_events = false

  # The server-access-log bucket exists, but in the SAME account — so a
  # compromised writer can still reach its own trail.
  create_access_log_bucket   = true
  enable_log_file_validation = false
  break_glass_arns           = []
}
