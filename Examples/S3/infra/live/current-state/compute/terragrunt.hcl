# F-13 · SSRF → instance-metadata credential theft (OWASP A01:2025)
#
# 04 §4.16b: this tier is the seven-version structural blind spot. It was never
# a listed open item — it simply had nowhere to live, because every earlier DFD
# jumped from "internet" straight to "S3".
#
# Draw it, and the entire credential-theft class becomes visible:
# the attacker never touches the bucket policy at all. They borrow an identity
# the bucket already trusts.

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

  # IMDSv1 still answers. A single proxied GET returns role credentials —
  # "IMDSv1 = no defense" (04 §4.16b).
  imdsv2_required = false

  # >1 means a proxied request can still reach IMDS even if v2 were required.
  metadata_hop_limit = 2

  # No egress block on the link-local range.
  block_link_local_egress = false
}
