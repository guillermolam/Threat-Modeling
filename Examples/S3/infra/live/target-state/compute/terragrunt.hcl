# F-13 · closed at the tier that owns it
#
# The mitigation is not on the bucket policy. It is IMDSv2 + hop limit 1 +
# least-privileging the role (done in ../iam) + blocking link-local egress.
#
# F-20 names this as one half of the cheapest pair of independent controls that
# breaks the APT chain: "IMDSv2 (step 1) + CloudTrail data events (step 4)".
# Both halves are in this stack.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/compute-tier"
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    app_compute_instance_profile = "mock-profile"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  instance_profile_name = dependency.iam.outputs.app_compute_instance_profile

  # A single proxied GET no longer works: IMDSv2 needs a PUT to get a token,
  # and hop limit 1 means a request relayed through the app never arrives.
  imdsv2_required    = true
  metadata_hop_limit = 1

  block_link_local_egress = true
}
