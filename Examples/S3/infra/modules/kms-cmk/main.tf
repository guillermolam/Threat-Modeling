# ---------------------------------------------------------------------------
# Module: kms-cmk — the SECOND access-control plane (04 §4.16c)
#
# For an SSE-KMS object, authorization happens twice on two independent planes:
# S3 authorizes the S3 action, then KMS separately authorizes the Decrypt.
# This module makes that second plane configurable so both the weak and the
# hardened posture can be stood up side by side.
#
# Findings implemented here:
#   ENC-2  AWS-managed key precludes key-policy control  (create_cmk = false)
#   ENC-3  Over-permissive key policy / :root delegation (delegate_to_account_root)
#   ENC-4  Missing kms:ViaService + encryption context   (require_via_service)
#   ENC-7  Crypto-shred via ScheduleKeyDeletion          (deny_key_lifecycle_ops)
#   ENC-8  Grant / key-policy persistence                (deny_grant_operations)
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  key_name   = "${var.name_prefix}-${var.tier}"
}

# ---------------------------------------------------------------------------
# PLANE 2 · The key policy.
#
# Read this top-down against the decision diagram in 04 §4.16c:
#   C1 "Principal allowed kms:Decrypt on this key?"
#   C2 "kms:ViaService pinned to s3.*?"
#   C3 "aws:SourceAccount + EncryptionContext enforced?"
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "key" {

  # -- Key administration. Always present; without it the key is orphaned. ---
  statement {
    sid       = "KeyAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = length(var.key_admin_arns) > 0 ? var.key_admin_arns : ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  # -- ENC-3 · the :root delegation door -----------------------------------
  # Granting Decrypt to :root delegates authorization to IAM, so ANY principal
  # in the account holding kms:Decrypt in an identity policy satisfies Plane 2 —
  # even though the bucket policy never granted them anything.
  dynamic "statement" {
    for_each = var.delegate_to_account_root ? [1] : []
    content {
      sid    = "ENC3_RootDelegationSecondFrontDoor"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${local.account_id}:root"]
      }
    }
  }

  # -- The hardened grant: named principals only ---------------------------
  # ENC-3 mitigation. Paired with ENC-4's conditions below.
  dynamic "statement" {
    for_each = length(var.decrypt_principal_arns) > 0 ? [1] : []
    content {
      sid    = "ScopedCryptographicUse"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.decrypt_principal_arns
      }

      # ENC-4 · C2 — pin the key to the S3 service. Without this, a principal
      # holding kms:Decrypt hands a ciphertext blob straight to the KMS API and
      # decrypts outside S3 — bypassing the bucket policy AND the access log.
      dynamic "condition" {
        for_each = var.require_via_service ? [1] : []
        content {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["s3.${var.aws_region}.amazonaws.com"]
        }
      }

      # ENC-4 · C3 — cross-account confused-deputy defence.
      dynamic "condition" {
        for_each = var.require_source_account ? [1] : []
        content {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [local.account_id]
        }
      }

      # ENC-4 · C3 — the encryption context (AAD) that scopes a key to one
      # prefix. Without it, one key decrypts everything it can reach rather
      # than only its intended scope.
      dynamic "condition" {
        for_each = var.required_encryption_context
        content {
          test     = "StringEquals"
          variable = "kms:EncryptionContext:${condition.key}"
          values   = [condition.value]
        }
      }
    }
  }

  # -- ENC-3 · the cross-account door (partner decrypt) --------------------
  # Present only when you deliberately model F-14's crypto crossing.
  dynamic "statement" {
    for_each = length(var.cross_account_principal_arns) > 0 ? [1] : []
    content {
      sid       = "ENC3_CrossAccountDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.cross_account_principal_arns
      }
    }
  }

  # -- ENC-7 · crypto-shred backstop ---------------------------------------
  # In real AWS this belongs in an SCP (04 §4.14 layer 1) so a compromised
  # deploy role at layer 4 cannot reach it. Floci has no Organizations, so the
  # lab places the equivalent Deny in the key policy and says so out loud.
  dynamic "statement" {
    for_each = var.deny_key_lifecycle_ops ? [1] : []
    content {
      sid    = "ENC7_DenyCryptoShredOutsideBreakGlass"
      effect = "Deny"
      actions = [
        "kms:ScheduleKeyDeletion",
        "kms:DisableKey",
        "kms:DeleteImportedKeyMaterial",
      ]
      resources = ["*"]
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

  # -- ENC-8 · grant & key-policy persistence ------------------------------
  # Grants are enumerated SEPARATELY from the key policy, so a routine
  # key-policy review misses a self-minted grant entirely.
  dynamic "statement" {
    for_each = var.deny_grant_operations ? [1] : []
    content {
      sid    = "ENC8_DenyGrantAndPolicyPersistence"
      effect = "Deny"
      actions = [
        "kms:CreateGrant",
        "kms:PutKeyPolicy",
      ]
      resources = ["*"]
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
}

# ---------------------------------------------------------------------------
# The key itself.
#
# create_cmk = false is ENC-2: you stay on the AWS-managed aws/s3 key, for
# which no key policy can be written at all. That is not a weaker key policy —
# it is the ABSENCE of the control surface, which is why ENC-2 is the
# prerequisite that blocks ENC-3/4/5/7/8 from being mitigable (13 §13.4).
# ---------------------------------------------------------------------------
resource "aws_kms_key" "this" {
  count = var.create_cmk ? 1 : 0

  description = "Meridian ${var.tier} tier CMK - ${var.posture} posture"
  policy      = data.aws_iam_policy_document.key.json

  # 13 §13.4 Level C — rotation period is configurable 90..2560 days since
  # April 2024. Rotation does NOT change the key ARN and does NOT require
  # re-encrypting existing objects.
  enable_key_rotation     = var.enable_key_rotation
  rotation_period_in_days = var.enable_key_rotation ? var.rotation_period_in_days : null

  # ENC-7 Level D — the deletion window is your only recovery time.
  deletion_window_in_days = var.deletion_window_in_days

  tags = merge(var.tags, {
    Name            = local.key_name
    SensitivityTier = var.tier
  })
}

resource "aws_kms_alias" "this" {
  count = var.create_cmk ? 1 : 0

  name          = "alias/${local.key_name}"
  target_key_id = aws_kms_key.this[0].key_id
}

# An intentional "no CMK" decision is still an architecture component: in
# current state it records ENC-2, while target public assets use SSE-S3 by
# classification. Keep that reviewed decision in the plan with the same model
# tags as a native key; it does not claim that Floci or AWS created a KMS key.
resource "terraform_data" "managed_key_decision" {
  count = var.create_cmk ? 0 : 1

  input = {
    key_strategy         = "provider-managed"
    sse_algorithm        = "AES256"
    sensitivity_tier     = var.tier
    customer_managed_key = false
    tags                 = var.tags
  }
}
