variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "posture" { type = string }
variable "floci_endpoint" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "managed_bucket_arns" {
  description = "Bucket ARNs this estate is scoped to."
  type        = list(string)
}

variable "kms_key_arns" {
  type    = list(string)
  default = []
}

variable "kms_key_arns_wildcard" {
  description = "F-13/F-18. true grants kms:Decrypt on \"*\" — the over-broad variant."
  type        = bool
  default     = false
}

# --- F-09 / F-17 -----------------------------------------------------------
variable "cicd_wildcard_resource" {
  description = "F-09. true = Resource \"*\" on the deploy role: a compromised pipeline rewrites the bucket policy of every bucket in the account."
  type        = bool
  default     = false
}

variable "cicd_oidc_subject" {
  description = "F-17. Scope the OIDC trust to repository AND branch. 'repo:org/name:*' would let any branch — or a fork's PR workflow — assume the deploy role."
  type        = string
  default     = "repo:meridian-retail/s3-platform:ref:refs/heads/main"
}

variable "scp_backstop_as_inline_deny" {
  description = "F-02/F-17. Floci has no Organizations, so the SCP backstop is expressed as an inline Deny on the deploy role. Not equivalent — see README 'Emulation gaps'."
  type        = bool
  default     = true
}

# --- F-13 ------------------------------------------------------------------
variable "compute_role_can_decrypt" {
  description = "F-13. Whether the instance role carries kms:Decrypt. The mitigation is to remove it if unused."
  type        = bool
  default     = false
}

variable "compute_read_prefix" {
  type    = string
  default = ""
}

# --- F-14 ------------------------------------------------------------------
variable "create_partner_role" {
  type    = bool
  default = true
}

variable "partner_principal_arn" {
  description = "The partner account principal allowed to assume the role."
  type        = string
  default     = "arn:aws:iam::000000000000:root"
}

variable "partner_external_id" {
  description = "F-14. null reproduces the confused deputy: any principal the partner can be tricked into invoking can assume the role."
  type        = string
  default     = null
}

variable "partner_require_source_account" {
  type    = bool
  default = true
}

variable "partner_cross_prefix_access" {
  description = "F-14. true = Resource bucket/* instead of bucket/partner/* — the partner can read /exports/ PII."
  type        = bool
  default     = false
}

variable "partner_prefix" {
  type    = string
  default = "partner/"
}

# --- F-18 ------------------------------------------------------------------
variable "create_agent_role" {
  type    = bool
  default = true
}

variable "agent_can_write" {
  description = "F-18. Least Agency: an injected instruction can move objects into /public/ or tamper with exports only if the role permits it."
  type        = bool
  default     = false
}

variable "agent_can_decrypt" {
  description = "F-18. Grants the agent kms:Decrypt — regulated data becomes reachable by prompt injection."
  type        = bool
  default     = false
}

# --- F-19 ------------------------------------------------------------------
variable "separate_duties" {
  description = "12 §12.5. false collapses the estate to one near-root role — session finding S6, and the enabler for F-19."
  type        = bool
  default     = true
}

# --- F-15 ------------------------------------------------------------------
variable "create_static_access_keys" {
  description = "F-15. Creates an IAM user with a long-lived access key — the credential that outlives employment."
  type        = bool
  default     = false
}
