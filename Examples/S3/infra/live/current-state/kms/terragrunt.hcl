# ENC-2 · AWS-managed key precludes key-policy control (the enabler)
#
# Finding S5: encryption uses the AWS-managed aws/s3 key. You cannot write a
# key policy for it, cannot apply kms:ViaService or aws:SourceAccount, cannot
# separate keys by sensitivity tier, cannot control deletion or rotation.
#
# This is not an exploit. It is the ABSENT CONTROL SURFACE that makes ENC-3,
# ENC-4, ENC-5, ENC-7 and ENC-8 unmitigatable until it is resolved — the
# crypto-plane analogue of LOG-1.
#
# Set create_cmk = true here to model the *naive migration*: a CMK exists, so
# ENC-3 and ENC-4 become expressible — and, left at these defaults, open.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/kms-cmk"
}

inputs = {
  tier = "mixed"

  # ENC-2 in one line.
  create_cmk = false

  # If you flip create_cmk to true, these are the ENC-3 / ENC-4 / ENC-7 / ENC-8
  # postures that the current-state estate would ship with — i.e. all open.
  delegate_to_account_root = true  # ENC-3 · :root delegation, the second front door
  require_via_service      = false # ENC-4 · decrypt can bypass S3 entirely
  require_source_account   = false # ENC-4 · no confused-deputy defence
  deny_key_lifecycle_ops   = false # ENC-7 · crypto-shred is one API call away
  deny_grant_operations    = false # ENC-8 · durable grants survive a policy review
  enable_key_rotation      = false
}
