# 04 §4.7 / §4.12 · the edge, with both halves of the origin lock
#
# This unit produces the distribution ARN; s3-public and s3-ugc consume it as
# cloudfront_distribution_arn. That wiring is the difference between "OAC is
# configured" and "the origin is actually closed" — the gap that current-state
# leaves open as attack-tree leaf 2.1.
#
# The origin bucket's domain name is COMPUTED rather than taken from a
# dependency, because the buckets depend on this unit for the ARN. Computing
# one side breaks the cycle.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/edge-cdn"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  root_vars   = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  name_prefix = "meridian-${local.env_vars.locals.short}"
  region      = get_env("AWS_REGION", "us-east-1")
}

inputs = {
  origin_bucket_name        = "${local.name_prefix}-public-assets"
  origin_bucket_domain_name = "${local.name_prefix}-public-assets.s3.${local.region}.amazonaws.com"

  enable_oac = true

  # F-03 · rate limiting is what makes "download the index" slow enough to
  # notice, even once the ListBucket deny is in place.
  enable_waf     = true
  waf_rate_limit = 2000

  # 04 §4.12 · a distinct cache behaviour for UGC, so attacker-influenced
  # content does not inherit the marketing path's caching and (absent)
  # signed-URL validation.
  separate_ugc_behavior = true
}
