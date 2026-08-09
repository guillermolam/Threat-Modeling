# 04 §4.7 · CloudFront in front — and the bypass that makes it decorative
#
# The distribution exists. OAC is even configured. But the bucket policy
# carries no condition tying reads to this distribution's ARN, so an attacker
# skips the CDN entirely — bypassing WAF, rate limiting, and CloudFront logging
# in one move. That is attack-tree leaf 2.1.
#
# Note what this unit deliberately does NOT do: it does not feed its
# distribution_arn back into s3-monolith. The wiring gap IS the finding.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/edge-cdn"
}

dependency "s3" {
  config_path = "../s3-monolith"
  mock_outputs = {
    bucket_name        = "mock-bucket"
    bucket_domain_name = "mock-bucket.s3.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  origin_bucket_name        = dependency.s3.outputs.bucket_name
  origin_bucket_domain_name = dependency.s3.outputs.bucket_domain_name

  enable_oac = true

  # No WAF, so nothing rate-limits F-03's enumeration.
  enable_waf = false

  # 04 §4.12 · /avatars/* and /public/* route through the same behaviour with
  # the same policy — one of the three things that file says to watch for.
  separate_ugc_behavior = false
}
