# "And alerting, not just logging" — LOG-1's last clause
#
# Every rule here is a named alarm from the findings register. 04 §4.15's
# "EventBridge alarm ⚠ configured?" — answered yes, and answered specifically:
# each rule cites the finding it defends, so a future reader can tell whether
# deleting it is a cleanup or a regression.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/detection"
}

inputs = {
  enable_alarms       = true
  enable_config_rules = true
}
