# Account A — bucket: public-assets (04 §4.10)
#
# "BPA on, no PII."
#
# Note the counterintuitive part: this bucket serves content to anonymous
# internet users, and Block Public Access is still ON. Public SERVING and
# public BUCKET POLICY are different things — CloudFront reads via OAC and the
# origin stays closed. Conflating the two is how F-01 happens on a bucket that
# only ever needed to serve marketing images.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/s3-data-bucket"
}

dependency "logging" {
  config_path = "../logging"
  mock_outputs = {
    access_log_bucket_name = "mock-logs"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "edge" {
  config_path = "../edge"
  mock_outputs = {
    distribution_arn = "arn:aws:cloudfront::000000000000:distribution/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  purpose        = "public-assets"
  classification = "public-no-pii"

  block_public_access  = true
  allow_anonymous_read = false # CloudFront reads via OAC, not the public
  allow_anonymous_list = false
  deny_anonymous_list  = true
  object_ownership     = "BucketOwnerEnforced"

  versioning_enabled = true

  # See kms-public/ for why this tier has no CMK. SSE-S3 is the right answer
  # for data with no confidentiality requirement.
  kms_key_arn            = null
  enforce_sse_kms_writes = false # would deny every write, since there is no CMK
  deny_sse_c             = true  # ENC-6 applies regardless of tier

  deny_insecure_transport = true
  minimum_tls_version     = "1.2"

  access_log_bucket = dependency.logging.outputs.access_log_bucket_name

  # 04 §4.7 · ties origin reads to this one distribution.
  cloudfront_distribution_arn = dependency.edge.outputs.distribution_arn

  seed_objects = {
    "public/marketing/spring-campaign.txt" = "Public marketing asset. No sensitivity."
  }
}
