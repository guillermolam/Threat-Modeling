# ---------------------------------------------------------------------------
# Module: detection — "and alerting, not just logging"
#
# LOG-1's mitigation ends with the sentence that makes this module necessary:
# "a log nobody reads is not a control." Every rule below corresponds to a
# named alarm in the findings register.
#
#   F-02   EventBridge alarm on PutBucketPublicAccessBlock
#   F-09   Alarm on PutBucketPolicy (the deploy path's own API call)
#   ENC-6  Alarm on bulk CopyObject/PutObject that changes encryption
#   ENC-7  Alarm on ScheduleKeyDeletion / DisableKey
#   ENC-8  Alarm on CreateGrant
#   S6     Alarm on kms:UpdateAlias (alias repoint to an attacker key, 13 §13.7)
#
# 04 §4.15 draws the alarm at the end of the deploy pipeline with a "⚠
# configured?" marker. This module is that question answered.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "security_alerts" {
  name = "${var.name_prefix}-security-alerts"
  tags = merge(var.tags, { Purpose = "security-alerting" })
}

locals {
  # Each rule: the API call, the finding it defends, and why it matters.
  detections = {
    public_access_block_changed = {
      finding     = "F-02"
      source      = "aws.s3"
      event_names = ["PutBucketPublicAccessBlock", "PutAccountPublicAccessBlock", "DeletePublicAccessBlock"]
      why         = "The backstop being removed is the moment of exposure, and it is otherwise silent."
    }
    bucket_policy_changed = {
      finding     = "F-01/F-09"
      source      = "aws.s3"
      event_names = ["PutBucketPolicy", "DeleteBucketPolicy"]
      why         = "A compromised deploy role's change arrives through the legitimate path and looks like a normal deploy."
    }
    bucket_acl_changed = {
      finding     = "04 §4.11"
      source      = "aws.s3"
      event_names = ["PutBucketAcl", "PutObjectAcl"]
      why         = "The legacy ACL path is the third independent way the public boundary fails (04 §4.8)."
    }
    kms_key_lifecycle = {
      finding     = "ENC-7"
      source      = "aws.kms"
      event_names = ["ScheduleKeyDeletion", "DisableKey", "DeleteImportedKeyMaterial"]
      why         = "Crypto-shred is permanent and versioning cannot undo it — the first signal is otherwise data that will not decrypt."
    }
    kms_grant_created = {
      finding     = "ENC-8"
      source      = "aws.kms"
      event_names = ["CreateGrant", "PutKeyPolicy"]
      why         = "Grants are enumerated separately from the key policy, so a routine policy review will not find one."
    }
    kms_alias_repointed = {
      finding     = "S6 / 13 §13.7"
      source      = "aws.kms"
      event_names = ["UpdateAlias"]
      why         = "An alias repoint makes every subsequent write attacker-decryptable while still looking encrypted in the console."
    }
    role_assumed_by_partner = {
      finding     = "F-14"
      source      = "aws.sts"
      event_names = ["AssumeRole"]
      why         = "Cross-account assumption is the confused deputy's first observable step."
    }
  }
}

resource "aws_cloudwatch_event_rule" "detection" {
  for_each = var.enable_alarms ? local.detections : {}

  name        = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  description = "${each.value.finding} - ${each.value.why}"

  event_pattern = jsonencode({
    source        = [each.value.source]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["${split(".", each.value.source)[1]}.amazonaws.com"]
      eventName   = each.value.event_names
    }
  })

  tags = merge(var.tags, {
    Finding = each.value.finding
  })
}

resource "aws_cloudwatch_event_target" "detection" {
  for_each = var.enable_alarms ? local.detections : {}

  rule      = aws_cloudwatch_event_rule.detection[each.key].name
  target_id = "sns"
  arn       = aws_sns_topic.security_alerts.arn
}

# ---------------------------------------------------------------------------
# AWS Config — "AWS Config rules for continuous verification" (F-01) and
# "automated remediation on drift".
#
# 14 (Continuous Threat Modeling) is the file that argues these exist at all:
# a control verified once at deploy time is a control that drifts.
# ---------------------------------------------------------------------------
resource "aws_config_config_rule" "managed" {
  for_each = var.enable_config_rules ? var.config_rules : {}

  name        = "${var.name_prefix}-${each.key}"
  description = each.value

  source {
    owner             = "AWS"
    source_identifier = each.key
  }

  tags = var.tags
}
