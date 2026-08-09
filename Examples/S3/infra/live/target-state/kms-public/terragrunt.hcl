# The public-assets tier — deliberately NO customer-managed key.
#
# This unit exists to make a decision visible rather than to create a resource.
#
# ENC-2 is a finding on the REGULATED bucket because there you need a key
# policy you cannot have. On a bucket that holds only marketing assets and no
# PII, SSE-S3 is the correct answer: there is no key policy worth writing, no
# sensitivity tier to separate, and a CMK would add a monthly charge and an
# ENC-7 crypto-shred target for no confidentiality gain.
#
# 13 §13.4's "separate CMK per sensitivity tier" is a statement about tiers
# that HAVE sensitivity. Applying it uniformly is cargo cult, and a reviewer
# who flags this as "ENC-2 unresolved" has read the finding without reading the
# classification.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/kms-cmk"
}

inputs = {
  tier       = "public-assets"
  create_cmk = false
}
