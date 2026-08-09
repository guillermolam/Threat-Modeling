# ---------------------------------------------------------------------------
# Module: s3-data-bucket — PLANE 1, the object store (04 §4.11)
#
# Findings implemented here:
#   F-01   Public bucket policy exposes PII        (allow_anonymous_read)
#   F-02   Block Public Access disabled            (block_public_access)
#   F-03   Public ListBucket enables enumeration   (allow_anonymous_list / deny_anonymous_list)
#   F-11   No versioning; ransomware unrecoverable (versioning_enabled, object_lock)
#   ENC-1  TLS not enforced by bucket policy       (deny_insecure_transport)
#   ENC-5  No write-time SSE enforcement           (enforce_sse_kms_writes, sanctioned key ARN)
#   ENC-6  SSE-C re-encryption ransomware          (deny_sse_c)
#   LOG-1  No object-level audit trail             (server access logging target)
#   P-01   Undefined retention per prefix          (lifecycle_rules)
#
# 04 §4.11 shows the internal evaluation order this module configures:
#   BPA -> bucket policy -> legacy ACL -> SSE -> object data
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name_prefix}-${var.purpose}"
  account_id  = data.aws_caller_identity.current.account_id
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"
  # Terragrunt dependency outputs must keep a stable string type. The KMS
  # module therefore emits "" when a tier deliberately uses SSE-S3; normalize
  # that sentinel here so it has exactly the same meaning as null.
  has_kms_key    = try(trimspace(var.kms_key_arn), "") != ""
  is_public_tier = startswith(var.classification, "public")

  # Whether we need to attach a bucket policy at all.
  has_policy = (
    var.allow_anonymous_read ||
    var.deny_anonymous_list ||
    var.deny_insecure_transport ||
    var.enforce_sse_kms_writes ||
    var.deny_sse_c ||
    var.cloudfront_distribution_arn != null ||
    length(var.read_principal_arns) > 0 ||
    length(var.write_principal_arns) > 0 ||
    length(var.extra_policy_statements) > 0
  )
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  # 13 §13.3 Level D — Object Lock forces versioning on and NEITHER can be
  # undone afterwards. Also: an Object Lock bucket cannot be a server-access-log
  # destination, which is a real architectural constraint if your log bucket and
  # data bucket were ever the same bucket.
  object_lock_enabled = var.object_lock_enabled

  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name           = local.bucket_name
    Classification = var.classification
    Purpose        = var.purpose
  })
}

# ---------------------------------------------------------------------------
# F-02 · Block Public Access — the backstop that makes a misconfigured bucket
# policy harmless. All four flags matter; the failure is silent.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

# ---------------------------------------------------------------------------
# 04 §4.11 · Object Ownership.
#
# The L2 decomposition surfaced a finding L1 could not: legacy ACL evaluation
# exists at all. BPA *overrides* ACLs; BucketOwnerEnforced *removes* them.
# Those are different security postures — only the second retires the code path.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = var.object_ownership
  }
}

# ---------------------------------------------------------------------------
# F-11 · Versioning. Prerequisite for Object Lock and for F-07's pinned-
# versionId fix. 13 §13.2 Level C: once enabled it can only be SUSPENDED,
# never returned to "never versioned".
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"

    # 13 §13.2 Level C — MFA Delete is configurable ONLY via CLI/API using the
    # bucket owner's root credentials with an MFA device. It is deliberately
    # NOT expressed here: see scripts/mfa-delete-breakglass.md for why this is
    # a logged root exception rather than a Terraform resource.
  }
}

# ---------------------------------------------------------------------------
# F-11 / ENC-6 · Object Lock (WORM). The strongest answer to the ransomware
# branch — and the one that collides with GDPR Art. 17 erasure (P-02).
#
# 13 §13.3: Compliance mode cannot be overridden by ANYONE, including root.
# Resolve the erasure conflict BEFORE choosing the mode.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.object_lock_enabled && var.object_lock_mode != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  rule {
    default_retention {
      mode = var.object_lock_mode # GOVERNANCE (overridable) | COMPLIANCE (not)
      days = var.object_lock_retention_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.this]
}

# ---------------------------------------------------------------------------
# ENC-2/ENC-5 · Default encryption.
#
# Setting the default is necessary but NOT sufficient: a default only applies
# when the caller omits the header. Refusing the wrong header is the bucket
# policy's job — see ENC5_* below.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.has_kms_key ? "aws:kms" : "AES256"
      kms_master_key_id = local.has_kms_key ? var.kms_key_arn : null
    }
    # 13 §13.4 Level D — Bucket Keys are a COST optimization, not a security
    # downgrade. They still enforce the same key policy. Noted so a reviewer
    # does not raise it as a finding.
    bucket_key_enabled = local.has_kms_key ? var.bucket_key_enabled : null
  }
}

# ---------------------------------------------------------------------------
# LOG-1 · Server access logging.
#
# The target bucket should live in a SEPARATE account so a compromised writer
# cannot erase its own trail. Floci is single-account, so the lab uses a
# separate bucket and flags the gap — see infra/README.md "Emulation gaps".
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_logging" "this" {
  count = var.access_log_bucket != null ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_log_bucket
  target_prefix = "s3-access/${local.bucket_name}/"
}

# ---------------------------------------------------------------------------
# P-01 / 13 §13.2 Level D · Lifecycle.
#
# Without noncurrent-version expiration, versioning grows cost without bound.
# But a cost rule written by someone who was not in the threat-modeling session
# can silently destroy incident-response evidence. Retain ~90 days and write
# down why — that is what noncurrent_version_expiration_days documents.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.use_native_lifecycle_resource && length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# Floci accepts the S3 lifecycle API but its provider refresh does not preserve
# aws_s3_bucket_lifecycle_configuration. Drive that same API explicitly so the
# lab remains warning-free without weakening or pretending to verify the rule.
locals {
  floci_lifecycle_configuration = {
    Rules = [
      for rule in var.lifecycle_rules : merge(
        {
          ID     = rule.id
          Status = "Enabled"
          Filter = { Prefix = rule.prefix }
        },
        rule.expiration_days != null ? {
          Expiration = { Days = rule.expiration_days }
        } : {},
        rule.noncurrent_version_expiration_days != null ? {
          NoncurrentVersionExpiration = {
            NoncurrentDays = rule.noncurrent_version_expiration_days
          }
        } : {}
      )
    ]
  }
}

resource "terraform_data" "floci_lifecycle" {
  count = !var.use_native_lifecycle_resource && length(var.lifecycle_rules) > 0 ? 1 : 0

  input = {
    bucket        = aws_s3_bucket.this.id
    configuration = jsonencode(local.floci_lifecycle_configuration)
    endpoint      = var.floci_endpoint
    region        = var.aws_region
  }

  triggers_replace = [
    aws_s3_bucket.this.id,
    jsonencode(local.floci_lifecycle_configuration),
  ]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      export AWS_ACCESS_KEY_ID=test
      export AWS_SECRET_ACCESS_KEY=test
      export AWS_REGION='${self.input.region}'
      export AWS_ENDPOINT_URL='${self.input.endpoint}'
      aws s3api put-bucket-lifecycle-configuration \
        --bucket '${self.input.bucket}' \
        --lifecycle-configuration '${self.input.configuration}' \
        >/dev/null
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      export AWS_ACCESS_KEY_ID=test
      export AWS_SECRET_ACCESS_KEY=test
      export AWS_REGION='${self.input.region}'
      export AWS_ENDPOINT_URL='${self.input.endpoint}'
      aws s3api delete-bucket-lifecycle --bucket '${self.input.bucket}' >/dev/null
    EOT
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# ---------------------------------------------------------------------------
# The bucket policy — PLANE 1's decisive control.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "bucket" {

  # -- F-01 · the front door ------------------------------------------------
  # "An attacker with no credentials discovers the bucket name ... downloads
  # customer records at will. No authentication step occurs, so no log entry
  # attributes the access to an identity."
  dynamic "statement" {
    for_each = var.allow_anonymous_read ? [1] : []
    content {
      sid       = "F01_AnonymousGetObject"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${local.bucket_arn}/*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
    }
  }

  # -- F-03 · "an attacker downloads the index" -----------------------------
  dynamic "statement" {
    for_each = var.allow_anonymous_list ? [1] : []
    content {
      sid       = "F03_AnonymousListBucket"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [local.bucket_arn]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
    }
  }

  # -- F-03 mitigation · explicit Deny regardless of the GetObject posture ---
  # An explicit Deny wins over every Allow at any layer (04 §4.14).
  dynamic "statement" {
    for_each = var.deny_anonymous_list ? [1] : []
    content {
      sid       = "F03_DenyAnonymousListBucket"
      effect    = "Deny"
      actions   = ["s3:ListBucket"]
      resources = [local.bucket_arn]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "StringNotEquals"
        variable = "aws:PrincipalAccount"
        values   = [local.account_id]
      }
    }
  }

  # -- ENC-1 · TLS ----------------------------------------------------------
  # "Protection depends on every caller behaving, rather than on the platform
  # refusing the insecure option."
  dynamic "statement" {
    for_each = var.deny_insecure_transport ? [1] : []
    content {
      sid       = "ENC1_DenyInsecureTransport"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [local.bucket_arn, "${local.bucket_arn}/*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.deny_insecure_transport && var.minimum_tls_version != null ? [1] : []
    content {
      sid       = "ENC1_DenyOldTlsVersions"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [local.bucket_arn, "${local.bucket_arn}/*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "NumericLessThan"
        variable = "s3:TlsVersion"
        values   = [var.minimum_tls_version]
      }
    }
  }

  # -- ENC-5 · write-time SSE enforcement -----------------------------------
  # Two statements, because there are two distinct downgrades:
  #   (a) no KMS header at all -> unencrypted or SSE-S3
  #   (b) a KMS header naming SOMEBODY ELSE'S key -> attacker-decryptable
  dynamic "statement" {
    for_each = var.enforce_sse_kms_writes ? [1] : []
    content {
      sid       = "ENC5_DenyWritesWithoutKmsSse"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${local.bucket_arn}/*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["aws:kms"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enforce_sse_kms_writes && local.has_kms_key ? [1] : []
    content {
      sid       = "ENC5_DenyWritesUnderUnsanctionedKey"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${local.bucket_arn}/*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [var.kms_key_arn]
      }
    }
  }

  # -- ENC-6 · SSE-C ransomware --------------------------------------------
  # With SSE-C the customer supplies the key on every request and AWS never
  # stores it. An attacker re-encrypts in place; the data stays intact but
  # becomes permanently unreadable to you. There is no platform recovery.
  dynamic "statement" {
    for_each = var.deny_sse_c ? [1] : []
    content {
      sid       = "ENC6_DenySseCustomerProvidedKeys"
      effect    = "Deny"
      actions   = ["s3:PutObject", "s3:GetObject"]
      resources = ["${local.bucket_arn}/*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "Null"
        variable = "s3:x-amz-server-side-encryption-customer-algorithm"
        values   = ["false"]
      }
    }
  }

  # -- 04 §4.7 · the CloudFront origin lock --------------------------------
  # OAC restricts CloudFront -> S3, but it does NOT by itself close the origin
  # to the internet. Without this condition an attacker skips the CDN entirely,
  # bypassing WAF, rate limiting and CloudFront logging in one move.
  dynamic "statement" {
    for_each = var.cloudfront_distribution_arn != null ? [1] : []
    content {
      sid       = "OAC_OnlyThisDistributionMayRead"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${local.bucket_arn}/*"]
      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [var.cloudfront_distribution_arn]
      }
    }
  }

  # -- Least-privilege named grants ----------------------------------------
  dynamic "statement" {
    for_each = length(var.read_principal_arns) > 0 ? [1] : []
    content {
      sid     = "ScopedRead"
      effect  = "Allow"
      actions = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"]
      resources = concat(
        [local.bucket_arn],
        [for p in var.read_prefixes : "${local.bucket_arn}/${p}*"]
      )
      principals {
        type        = "AWS"
        identifiers = var.read_principal_arns
      }
    }
  }

  # F-14 mitigation · "a single write-only prefix, no read, no cross-prefix".
  dynamic "statement" {
    for_each = length(var.write_principal_arns) > 0 ? [1] : []
    content {
      sid       = "ScopedWriteOnly"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = [for p in var.write_prefixes : "${local.bucket_arn}/${p}*"]
      principals {
        type        = "AWS"
        identifiers = var.write_principal_arns
      }
    }
  }

  # -- Escape hatch for per-unit statements --------------------------------
  dynamic "statement" {
    for_each = var.extra_policy_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
      principals {
        type        = statement.value.principal_type
        identifiers = statement.value.principal_identifiers
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = local.has_policy ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json

  # BPA's block_public_policy would reject a public policy, so the ordering
  # matters: apply the access block first, then the policy.
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# ---------------------------------------------------------------------------
# Seed objects — so the lab has something to actually exfiltrate.
# Synthetic data only; see scripts/seed-data.sh for the fixture contents.
# ---------------------------------------------------------------------------
resource "aws_s3_object" "seed" {
  for_each = var.seed_objects

  bucket       = aws_s3_bucket.this.id
  key          = each.key
  content      = each.value
  content_type = "text/plain"

  depends_on = [aws_s3_bucket_policy.this]
}
