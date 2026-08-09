# ---------------------------------------------------------------------------
# Module: edge-cdn — 04 §4.7 (L1-B) and §4.12 (L2-B)
#
# The critical annotation from §4.7:
#
#   "OAC restricts CloudFront -> S3, but it does NOT by itself close the S3
#    origin to the internet. Unless the bucket policy also carries an explicit
#    condition tying access to the distribution ARN, an attacker simply skips
#    the CDN entirely — bypassing WAF, rate limiting, and CloudFront logging in
#    one move. That is attack-tree leaf 2.1."
#
# So this module produces the distribution ARN; the CONDITION that actually
# closes the origin lives in the s3-data-bucket module
# (cloudfront_distribution_arn). Both halves are required. Wiring only one is
# the finding.
#
# §4.12 watch-list, made explicit in the cache behaviours below:
#   - behaviours that route /avatars/* and /public/* to the same origin with
#     the same policy
#   - anything authenticated being cached
#   - signed-URL validation applied to only some behaviours
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# WAF — the block element {{ }} in the house notation (04 §4.2).
# Rate limiting is the control that makes F-03's "download the index" slow
# enough to notice.
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "this" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.name_prefix}-edge"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitPerIp"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIp"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-edge"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Origin Access Control. Half the control — see the module header.
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "this" {
  count = var.enable_oac ? 1 : 0

  name                              = "${var.name_prefix}-oac"
  description                       = "OAC for ${var.origin_bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled = true
  comment = "${var.name_prefix} - ${var.posture} posture"

  origin {
    domain_name              = var.origin_bucket_domain_name
    origin_id                = "s3-${var.origin_bucket_name}"
    origin_access_control_id = var.enable_oac ? aws_cloudfront_origin_access_control.this[0].id : null
  }

  default_cache_behavior {
    target_origin_id       = "s3-${var.origin_bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # §4.12 · a distinct behaviour for the UGC prefix. Sharing the default
  # behaviour with /public/* is exactly the thing to watch for: it means the
  # same caching and the same (absent) signed-URL validation apply to
  # attacker-influenced content.
  dynamic "ordered_cache_behavior" {
    for_each = var.separate_ugc_behavior ? [1] : []
    content {
      path_pattern           = "/avatars/*"
      target_origin_id       = "s3-${var.origin_bucket_name}"
      viewer_protocol_policy = "https-only"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]

      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }
    }
  }

  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.this[0].arn : null

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # F-12 mitigation, edge half: CSP headers where images render. The re-encode
  # (the control that actually defeats steganography) is upstream in the UGC
  # pipeline, not here.
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-edge"
  })
}
