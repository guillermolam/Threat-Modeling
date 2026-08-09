# These return "" rather than null when no CMK exists. Terraform omits null
# outputs from the state's output map entirely, which makes
# `dependency.kms.outputs.key_arn` an "unsupported attribute" error in the
# consuming Terragrunt unit rather than a null value. Empty string keeps the
# attribute present; s3-data-bucket treats "" and null identically.
output "key_id" {
  value       = var.create_cmk ? aws_kms_key.this[0].key_id : ""
  description = "Empty when create_cmk = false (ENC-2: the AWS-managed aws/s3 key is in use)."
}

output "key_arn" {
  value = var.create_cmk ? aws_kms_key.this[0].arn : ""
}

output "alias_name" {
  value = var.create_cmk ? aws_kms_alias.this[0].name : ""
}

output "sse_algorithm" {
  description = "Feeds the bucket's default encryption. aws:kms when a CMK exists, AES256 otherwise."
  value       = var.create_cmk ? "aws:kms" : "AES256"
}

output "posture_note" {
  value = var.create_cmk ? "CMK in use — key policy is writable, ENC-3/4/7/8 controls apply." : "ENC-2: AWS-managed aws/s3 key. No key policy exists to harden."
}
