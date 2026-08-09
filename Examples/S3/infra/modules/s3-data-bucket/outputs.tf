output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  value = aws_s3_bucket.this.bucket_regional_domain_name
}

output "policy_json" {
  description = "The rendered bucket policy — diff this between postures to see F-01/F-03/ENC-1/ENC-5/ENC-6 appear and disappear."
  value       = local.has_policy ? data.aws_iam_policy_document.bucket.json : null
}

output "posture_summary" {
  description = "Which findings are OPEN on this bucket as configured."
  value = compact([
    var.allow_anonymous_read ? "F-01 OPEN: anonymous s3:GetObject" : null,
    !var.block_public_access ? "F-02 OPEN: Block Public Access disabled" : null,
    var.allow_anonymous_list ? "F-03 OPEN: anonymous s3:ListBucket" : null,
    !var.versioning_enabled ? "F-11 OPEN: versioning off" : null,
    !var.deny_insecure_transport ? "ENC-1 OPEN: TLS not policy-enforced" : null,
    var.kms_key_arn == null ? "ENC-2 OPEN: no CMK (AWS-managed key)" : null,
    !var.enforce_sse_kms_writes ? "ENC-5 OPEN: no write-time SSE enforcement" : null,
    !var.deny_sse_c ? "ENC-6 OPEN: SSE-C not denied" : null,
    var.access_log_bucket == null ? "LOG-1 partial: no server access logging" : null,
    var.object_ownership != "BucketOwnerEnforced" ? "04 §4.11: legacy ACL path still live" : null,
  ])
}
