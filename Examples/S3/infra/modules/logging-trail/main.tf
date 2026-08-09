# ---------------------------------------------------------------------------
# Module: logging-trail — LOG-1
#
# "Management events record CHANGES TO the bucket; data events record ACCESS TO
# objects." Without data events, an attacker who reads every customer record
# leaves no trace distinguishable from ordinary traffic.
#
# LOG-1 is not a standalone breach — it is the force multiplier that converts
# every other finding from a detectable incident into an undetectable one, and
# it eliminates the evidence needed for breach-notification scoping.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  trail_name  = "${var.name_prefix}-trail"
  bucket_name = "${var.name_prefix}-cloudtrail"
}

# ---------------------------------------------------------------------------
# The trail's own destination bucket.
#
# LOG-1 mitigation says this belongs in a SEPARATE ACCOUNT so a compromised
# writer cannot erase its own trail. Floci is single-account; the lab gets the
# bucket separation but not the account separation. Flagged in README.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "trail" {
  bucket        = local.bucket_name
  force_destroy = true
  tags = merge(var.tags, {
    Name    = local.bucket_name
    Purpose = "cloudtrail-destination"
    Finding = "LOG-1"
  })
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # A compromised writer must not be able to erase its own trail.
  statement {
    sid       = "LOG1_DenyTrailDeletion"
    effect    = "Deny"
    actions   = ["s3:DeleteObject", "s3:DeleteObjectVersion", "s3:PutBucketPolicy"]
    resources = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    dynamic "condition" {
      for_each = length(var.break_glass_arns) > 0 ? [1] : []
      content {
        test     = "ArnNotEquals"
        variable = "aws:PrincipalArn"
        values   = var.break_glass_arns
      }
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket     = aws_s3_bucket.trail.id
  policy     = data.aws_iam_policy_document.trail_bucket.json
  depends_on = [aws_s3_bucket_public_access_block.trail]
}

# ---------------------------------------------------------------------------
# Server access log destination — distinct from the CloudTrail bucket.
#
# 13 §13.3 Level D: an Object Lock bucket CANNOT be a server-access-log
# destination. That is why this is its own bucket and never carries Object Lock.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "access_logs" {
  count = var.create_access_log_bucket ? 1 : 0

  bucket        = "${var.name_prefix}-access-logs"
  force_destroy = true
  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-access-logs"
    Purpose = "s3-server-access-logs"
    Note    = "Never Object-Lock this bucket — 13 §13.3 Level D."
  })
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count = var.create_access_log_bucket ? 1 : 0

  bucket                  = aws_s3_bucket.access_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  count = var.create_access_log_bucket ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id
  rule {
    # S3 log delivery writes with an ACL, so this bucket is the one place the
    # legacy ACL path is deliberately left available.
    object_ownership = "BucketOwnerPreferred"
  }
}

# ---------------------------------------------------------------------------
# The trail.
#
# enable_data_events = false IS finding LOG-1. Management events still flow,
# which is precisely the trap: the console shows "CloudTrail: enabled" while
# every object read goes unrecorded.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "trail" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/cloudtrail/${local.trail_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# LOG-1 · the data-event selector. This is the whole finding, in one structure.
locals {
  data_event_values = length(var.data_event_bucket_arns) > 0 ? [
    for a in var.data_event_bucket_arns : "${a}/"
  ] : ["arn:${data.aws_partition.current.partition}:s3:::"]

  event_selectors = var.enable_data_events ? [{
    ReadWriteType           = "All"
    IncludeManagementEvents = true
    DataResources = [{
      Type   = "AWS::S3::Object"
      Values = local.data_event_values
    }]
    }] : [{
    # Management events only — the LOG-1 posture. Changes TO the bucket are
    # recorded; access TO objects is not.
    ReadWriteType           = "All"
    IncludeManagementEvents = true
    DataResources           = []
  }]

  trail_arn = "arn:${data.aws_partition.current.partition}:cloudtrail:${var.aws_region}:${local.account_id}:trail/${local.trail_name}"
}

# ---------------------------------------------------------------------------
# Native resource — correct for real AWS, unusable against Floci.
#
# The AWS provider calls cloudtrail:ListTags on every read of this resource,
# whether or not it is tagged. Floci does not implement ListTags, so the read
# fails and the whole stack becomes unappliable. Set use_native_trail_resource
# = true when pointing this code at a real account.
# ---------------------------------------------------------------------------
resource "aws_cloudtrail" "this" {
  count = var.use_native_trail_resource ? 1 : 0

  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = var.multi_region
  enable_log_file_validation    = var.enable_log_file_validation
  enable_logging                = true

  dynamic "event_selector" {
    for_each = local.event_selectors
    content {
      read_write_type           = event_selector.value.ReadWriteType
      include_management_events = event_selector.value.IncludeManagementEvents

      dynamic "data_resource" {
        for_each = event_selector.value.DataResources
        content {
          type   = data_resource.value.Type
          values = data_resource.value.Values
        }
      }
    }
  }

  tags = merge(var.tags, { Finding = "LOG-1" })

  depends_on = [aws_s3_bucket_policy.trail]
}

# ---------------------------------------------------------------------------
# Floci path — the same trail, driven through the CLI.
#
# create-trail, put-event-selectors and start-logging are all implemented by
# the emulator; only the tag read is not. This keeps LOG-1 genuinely testable
# (you can flip enable_data_events and watch get-event-selectors change)
# without pretending the provider works when it does not.
# ---------------------------------------------------------------------------
resource "terraform_data" "trail" {
  count = var.use_native_trail_resource ? 0 : 1

  input = {
    name       = local.trail_name
    bucket     = aws_s3_bucket.trail.id
    endpoint   = var.floci_endpoint
    region     = var.aws_region
    selectors  = jsonencode(local.event_selectors)
    multi      = var.multi_region
    validation = var.enable_log_file_validation
  }

  triggers_replace = [
    local.trail_name,
    aws_s3_bucket.trail.id,
    jsonencode(local.event_selectors),
    var.enable_log_file_validation,
  ]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      export AWS_ACCESS_KEY_ID=test
      export AWS_SECRET_ACCESS_KEY=test
      export AWS_REGION='${self.input.region}'
      export AWS_ENDPOINT_URL='${self.input.endpoint}'

      existing_trail="$(aws cloudtrail describe-trails \
        --trail-name-list '${self.input.name}' \
        --query "trailList[?Name=='${self.input.name}'].Name | [0]" \
        --output text)"
      if [[ "$${existing_trail}" == '${self.input.name}' ]]; then
        aws cloudtrail delete-trail --name '${self.input.name}' >/dev/null
      fi

      aws cloudtrail create-trail \
        --name '${self.input.name}' \
        --s3-bucket-name '${self.input.bucket}' \
        --include-global-service-events \
        ${self.input.multi ? "--is-multi-region-trail" : "--no-is-multi-region-trail"} \
        ${self.input.validation ? "--enable-log-file-validation" : "--no-enable-log-file-validation"} \
        >/dev/null

      aws cloudtrail put-event-selectors \
        --trail-name '${self.input.name}' \
        --event-selectors '${self.input.selectors}' \
        >/dev/null

      aws cloudtrail start-logging --name '${self.input.name}'
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
      existing_trail="$(aws cloudtrail describe-trails \
        --trail-name-list '${self.input.name}' \
        --query "trailList[?Name=='${self.input.name}'].Name | [0]" \
        --output text)"
      if [[ "$${existing_trail}" == '${self.input.name}' ]]; then
        aws cloudtrail delete-trail --name '${self.input.name}' >/dev/null
      fi
    EOT
  }

  depends_on = [aws_s3_bucket_policy.trail]
}
