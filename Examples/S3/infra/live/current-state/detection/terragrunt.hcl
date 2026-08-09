# 04 §4.15 · "EventBridge alarm ⚠ configured?"
#
# The L3-B deploy-pipeline diagram ends with three question marks on one path,
# and this is the last of them. Answered here: no.
#
# The SNS topic is still created so the target-state diff is about the RULES
# rather than about the plumbing.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/detection"
}

inputs = {
  # LOG-1: "a log nobody reads is not a control."
  enable_alarms       = false
  enable_config_rules = false
}
