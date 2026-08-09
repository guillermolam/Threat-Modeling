# ---------------------------------------------------------------------------
# Module: iam-estate — the identity plane
#
# Current-state starts from session finding S6: AWS is root-user-only, no IAM
# roles beyond defaults. 12 §12.1: "'We don't have IAM set up yet' is a reason
# to design it now, not to defer it."
#
# Target-state implements the 12 §12.5 role table verbatim. Every role below is
# derived from a risk-register owner or a DFD actor — none is invented
# generically (12 §12.2).
#
# Findings implemented here:
#   F-09  CI/CD deploy role scope unverified   (cicd_wildcard_resource)
#   F-13  Compute role blast radius            (compute_role_can_decrypt)
#   F-14  Partner confused deputy              (partner_external_id, partner prefix scope)
#   F-15  Departed employee / long-lived keys  (create_static_access_keys)
#   F-18  Agent excessive agency               (agent_can_write, agent_can_decrypt)
#   F-19  Insider bulk access, no SoD          (separate_duties)
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # F-09 · "The finding is that we do not know." The wildcard variant is what
  # an unverified deploy role looks like once you actually write it down.
  cicd_resources = var.cicd_wildcard_resource ? ["*"] : concat(
    var.managed_bucket_arns,
    [for a in var.managed_bucket_arns : "${a}/*"]
  )

  # F-14 · role scope. bucket/* lets the partner read /exports/ PII;
  # bucket/partner/* is the intended write-only target.
  partner_resources = var.partner_cross_prefix_access ? [
    for a in var.managed_bucket_arns : "${a}/*"
    ] : [
    for a in var.managed_bucket_arns : "${a}/${var.partner_prefix}*"
  ]
}

# ===========================================================================
# MACHINE IDENTITY — deliberately NOT routed through the human path (12 §12.4)
# ===========================================================================

# ---------------------------------------------------------------------------
# F-09 / F-17 · S3-CustomerData-CICD-Deploy
#
# OIDC federation correctly avoids long-lived credentials. The finding is the
# Resource element. If wildcarded, an attacker who compromises the CI/CD
# platform rewrites the bucket policy of EVERY bucket in the account — and it
# appears in CloudTrail as a normal deploy.
#
# F-17 mitigation: scope the OIDC trust to repository AND branch, not just repo.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "cicd_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      # F-17 · repo *and* branch. `repo:org/name:*` would let any branch — or a
      # fork's PR workflow — assume the deploy role.
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.cicd_oidc_subject]
    }
  }
}

resource "aws_iam_role" "cicd_deploy" {
  name                 = "${var.name_prefix}-cicd-deploy"
  assume_role_policy   = data.aws_iam_policy_document.cicd_trust.json
  max_session_duration = 3600
  tags = merge(var.tags, {
    Finding     = "F-09"
    AccessModel = "WorkloadOIDC"
  })
}

data "aws_iam_policy_document" "cicd_deploy" {
  statement {
    sid    = "DeployBucketConfiguration"
    effect = "Allow"
    actions = [
      "s3:PutBucketPolicy",
      "s3:GetBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:GetBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:GetEncryptionConfiguration",
    ]
    resources = local.cicd_resources
  }

  # F-02 / F-17 backstop. In real AWS this belongs in an SCP (04 §4.14 layer 1)
  # so even a compromised apply cannot reach it. Floci has no Organizations, so
  # the lab expresses it as an inline Deny and flags the difference.
  dynamic "statement" {
    for_each = var.scp_backstop_as_inline_deny ? [1] : []
    content {
      sid    = "F02_BackstopCannotDisableBlockPublicAccess"
      effect = "Deny"
      actions = [
        "s3:PutBucketPublicAccessBlock",
        "s3:PutAccountPublicAccessBlock",
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "cicd_deploy" {
  name   = "deploy"
  role   = aws_iam_role.cicd_deploy.id
  policy = data.aws_iam_policy_document.cicd_deploy.json
}

# ---------------------------------------------------------------------------
# F-13 · Application compute role (04 §4.16b)
#
# This is the role SSRF steals. Once stolen, its calls are indistinguishable
# from the application in CloudTrail — "the attacker borrows an identity the
# bucket already trusts."
#
# The mitigation is not on the bucket policy at all: it is least-privileging
# THIS role, and removing kms:Decrypt if unused.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "compute_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_compute" {
  name               = "${var.name_prefix}-app-compute"
  assume_role_policy = data.aws_iam_policy_document.compute_trust.json
  tags = merge(var.tags, {
    Finding = "F-13"
    Actor   = "A-10 Compromised Compute Role"
  })
}

data "aws_iam_policy_document" "app_compute" {
  statement {
    sid       = "ReadApplicationObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [for a in var.managed_bucket_arns : "${a}/${var.compute_read_prefix}*"]
  }

  # F-13 · "if the role carries kms:Decrypt, reads encrypted data too."
  dynamic "statement" {
    for_each = var.compute_role_can_decrypt ? [1] : []
    content {
      sid       = "F13_DecryptBlastRadius"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = var.kms_key_arns_wildcard ? ["*"] : var.kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "app_compute" {
  name   = "app"
  role   = aws_iam_role.app_compute.id
  policy = data.aws_iam_policy_document.app_compute.json
}

resource "aws_iam_instance_profile" "app_compute" {
  name = "${var.name_prefix}-app-compute"
  role = aws_iam_role.app_compute.name
}

# ---------------------------------------------------------------------------
# F-14 · Partner / vendor cross-account role (04 §4.16a)
#
# The classic confused deputy. Two independent things go wrong:
#   1. No sts:ExternalId  -> any principal the partner can be tricked into
#                            invoking can assume the role
#   2. Resource = bucket/* -> the partner reads /exports/ PII
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "partner_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.partner_principal_arn]
    }

    dynamic "condition" {
      for_each = var.partner_external_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.partner_external_id]
      }
    }

    dynamic "condition" {
      for_each = var.partner_require_source_account ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_iam_role" "partner_write" {
  count = var.create_partner_role ? 1 : 0

  name               = "${var.name_prefix}-partner-write"
  assume_role_policy = data.aws_iam_policy_document.partner_trust.json
  tags = merge(var.tags, {
    Finding = "F-14"
    Actor   = "A-5 Partner / Vendor"
  })
}

data "aws_iam_policy_document" "partner_write" {
  statement {
    sid    = "PartnerPrefixAccess"
    effect = "Allow"
    # Write-only is the intended posture. Read is what turns F-14 critical.
    actions   = var.partner_cross_prefix_access ? ["s3:PutObject", "s3:GetObject", "s3:ListBucket"] : ["s3:PutObject"]
    resources = local.partner_resources
  }
}

resource "aws_iam_role_policy" "partner_write" {
  count = var.create_partner_role ? 1 : 0

  name   = "partner"
  role   = aws_iam_role.partner_write[0].id
  policy = data.aws_iam_policy_document.partner_write.json
}

# ---------------------------------------------------------------------------
# F-18 · Autonomous analytics agent (04 §4.16d)
#
# "The agent's authority = its blast radius." The Least Agency principle says
# read is autonomous; write / delete / decrypt is gated behind a human.
# There is no IAM primitive for "human-in-the-loop", so the lab enforces the
# only half IAM CAN enforce — removing the permissions entirely — and records
# the gate as an assumption in the threat model.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "agent_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "analytics_agent" {
  count = var.create_agent_role ? 1 : 0

  name               = "${var.name_prefix}-analytics-agent"
  assume_role_policy = data.aws_iam_policy_document.agent_trust.json
  tags = merge(var.tags, {
    Finding = "F-18"
    Actor   = "A-6 Autonomous Analytics Agent"
  })
}

data "aws_iam_policy_document" "analytics_agent" {
  statement {
    sid       = "AgentRead"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = concat(var.managed_bucket_arns, [for a in var.managed_bucket_arns : "${a}/*"])
  }

  dynamic "statement" {
    for_each = var.agent_can_write ? [1] : []
    content {
      sid       = "F18_AgentWriteExcessiveAgency"
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:DeleteObject"]
      resources = [for a in var.managed_bucket_arns : "${a}/*"]
    }
  }

  dynamic "statement" {
    for_each = var.agent_can_decrypt ? [1] : []
    content {
      sid       = "F18_AgentDecryptExcessiveAgency"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.kms_key_arns_wildcard ? ["*"] : var.kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "analytics_agent" {
  count = var.create_agent_role ? 1 : 0

  name   = "agent"
  role   = aws_iam_role.analytics_agent[0].id
  policy = data.aws_iam_policy_document.analytics_agent.json
}

# ---------------------------------------------------------------------------
# F-07 · Analytics reader service
#
# The TOCTOU is in the SERVICE's logic, not in IAM. What IAM contributes is the
# structural half of the fix: "remove PutObject on the export prefix from every
# principal except the writer service." So this role is read-only by
# construction, and the reader is expected to pin an ETag or versionId.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "analytics_reader" {
  name               = "${var.name_prefix}-analytics-reader"
  assume_role_policy = data.aws_iam_policy_document.agent_trust.json
  tags = merge(var.tags, {
    Finding = "F-07"
  })
}

data "aws_iam_policy_document" "analytics_reader" {
  statement {
    sid     = "ReadExportsWithVersionPinning"
    effect  = "Allow"
    actions = ["s3:ListBucket", "s3:GetObject", "s3:GetObjectVersion"]
    resources = concat(
      var.managed_bucket_arns,
      [for a in var.managed_bucket_arns : "${a}/exports/*"]
    )
  }
}

resource "aws_iam_role_policy" "analytics_reader" {
  name   = "reader"
  role   = aws_iam_role.analytics_reader.id
  policy = data.aws_iam_policy_document.analytics_reader.json
}

# ===========================================================================
# HUMAN IDENTITY — the 12 §12.5 table
#
# In production these are assumed via Entra ID -> Conditional Access / PIM ->
# IAM Identity Center. Floci has no Identity Center, so the trust policy below
# stands in for the federated principal and the PIM properties are carried as
# tags. See README "Emulation gaps".
# ===========================================================================

data "aws_iam_policy_document" "human_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    # Stand-in for Conditional Access "MFA required" (12 §12.7 / IAM-1).
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

locals {
  # 12 §12.5. separate_duties = false collapses these into one near-root role,
  # which IS finding F-19 / session finding S6.
  human_roles = var.separate_duties ? {
    readonly = {
      # "s3:GetObject on specific prefix. No ListBucket."
      actions      = ["s3:GetObject"]
      resource_fmt = "objects"
      access_model = "Standing"
      entra_group  = "SEC-S3-ReadOnly-Engineers"
      session      = 28800 # 8h (12 §12.7)
    }
    admin = {
      actions      = ["s3:*"]
      resource_fmt = "both"
      access_model = "PIM"
      entra_group  = "SEC-S3-Admin-PIM"
      session      = 14400 # 4h max
    }
    securityaudit = {
      # The subtle one: can see the CONFIGURATION but not the DATA.
      actions = [
        "s3:GetBucketPolicy",
        "s3:GetBucketAcl",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:ListBucket",
      ]
      resource_fmt = "both"
      access_model = "Standing"
      entra_group  = "SEC-S3-SecurityAudit"
      session      = 28800
    }
    incidentresponder = {
      actions      = ["s3:*", "kms:Describe*", "kms:List*"]
      resource_fmt = "both"
      access_model = "PIM"
      entra_group  = "SEC-S3-IncidentResponse"
      session      = 7200 # 2h max
    }
    privacyops = {
      # P-02: version-aware delete on specific keys; no bulk read.
      actions      = ["s3:DeleteObject", "s3:DeleteObjectVersion", "s3:ListBucketVersions"]
      resource_fmt = "both"
      access_model = "PIM"
      entra_group  = "SEC-S3-PrivacyOps"
      session      = 7200
    }
    } : {
    # F-19 / S6 — the flat estate. One role, everything, no self-approval check.
    admin = {
      actions      = ["s3:*", "kms:*", "iam:*"]
      resource_fmt = "wildcard"
      access_model = "Standing"
      entra_group  = "(none — no separation of duties)"
      session      = 43200
    }
  }
}

resource "aws_iam_role" "human" {
  for_each = local.human_roles

  name                 = "${var.name_prefix}-${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.human_trust.json
  max_session_duration = each.value.session

  tags = merge(var.tags, {
    Function    = each.key
    AccessModel = each.value.access_model
    EntraGroup  = each.value.entra_group
    # 12 §12.7 — reviewed every 90 days (IAM-6). Carried as a tag because the
    # review itself is a process control, not an API call.
    AccessReview = "90d"
  })
}

resource "aws_iam_role_policy" "human" {
  for_each = local.human_roles

  name = "access"
  role = aws_iam_role.human[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ScopedAccess"
      Effect = "Allow"
      Action = each.value.actions
      Resource = (
        each.value.resource_fmt == "wildcard" ? ["*"] :
        each.value.resource_fmt == "objects" ? [for a in var.managed_bucket_arns : "${a}/*"] :
        concat(var.managed_bucket_arns, [for a in var.managed_bucket_arns : "${a}/*"])
      )
    }]
  })
}

# ---------------------------------------------------------------------------
# F-15 · Departed employee / no joiner-mover-leaver
#
# A-8 is "a time-shifted insider" whose distinguishing means is a long-lived
# credential that outlives the employment relationship. Federation with
# short-lived credentials collapses this actor almost to zero — which is the
# strongest argument for retiring IAM users entirely (12 §12.9 step 5).
#
# create_static_access_keys = true reproduces the credential that should not
# exist, so the finding is demonstrable rather than theoretical.
# ---------------------------------------------------------------------------
resource "aws_iam_user" "legacy_operator" {
  count = var.create_static_access_keys ? 1 : 0

  name = "${var.name_prefix}-legacy-operator"
  tags = merge(var.tags, {
    Finding = "F-15"
    Actor   = "A-8 Departed Employee"
    Note    = "Long-lived credential with no JML deprovisioning — this is the finding."
  })
}

resource "aws_iam_access_key" "legacy_operator" {
  count = var.create_static_access_keys ? 1 : 0
  user  = aws_iam_user.legacy_operator[0].name
}

resource "aws_iam_user_policy" "legacy_operator" {
  count = var.create_static_access_keys ? 1 : 0

  name = "legacy"
  user = aws_iam_user.legacy_operator[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = concat(var.managed_bucket_arns, [for a in var.managed_bucket_arns : "${a}/*"])
    }]
  })
}
