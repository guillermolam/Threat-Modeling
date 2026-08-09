output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "Feed this into s3-data-bucket.cloudfront_distribution_arn — without that condition the origin stays open to the internet (04 §4.7, attack-tree leaf 2.1)."
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "web_acl_arn" {
  value = var.enable_waf ? aws_wafv2_web_acl.this[0].arn : null
}

output "posture_summary" {
  value = compact([
    !var.enable_oac ? "04 §4.7 OPEN: no OAC — origin reachable directly" : null,
    !var.enable_waf ? "No WAF: no rate limiting in front of enumeration" : null,
    !var.separate_ugc_behavior ? "04 §4.12: /avatars/* shares the default cache behaviour with /public/*" : null,
  ])
}
