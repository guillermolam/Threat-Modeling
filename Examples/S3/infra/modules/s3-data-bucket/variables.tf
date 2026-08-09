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

variable "purpose" {
  description = "Bucket role: public-assets | user-content | customer-exports | access-logs | quarantine | monolith"
  type        = string
}

variable "classification" {
  description = "04 §4.6 — one data store holding three classifications is the single highest-leverage finding in the guide. 'mixed' is itself the finding."
  type        = string
  default     = "unclassified"
}

variable "force_destroy" {
  description = "Lab convenience so `terragrunt destroy` works. Never true on a real regulated bucket."
  type        = bool
  default     = true
}

# --- F-02 ------------------------------------------------------------------
variable "block_public_access" {
  description = "F-02. All four BPA flags. false is the finding: a single incorrect policy change immediately exposes the bucket, with no second control in between."
  type        = bool
  default     = true
}

# --- 04 §4.11 legacy ACL plane --------------------------------------------
variable "object_ownership" {
  description = "BucketOwnerEnforced REMOVES the legacy ACL code path. ObjectWriter / BucketOwnerPreferred keep it alive for BPA to override."
  type        = string
  default     = "BucketOwnerEnforced"
}

# --- F-01 / F-03 -----------------------------------------------------------
variable "allow_anonymous_read" {
  description = "F-01. Grant s3:GetObject to Principal '*'."
  type        = bool
  default     = false
}

variable "allow_anonymous_list" {
  description = "F-03. Grant s3:ListBucket to Principal '*' — turns 'guess file names' into 'download the index'."
  type        = bool
  default     = false
}

variable "deny_anonymous_list" {
  description = "F-03 mitigation. Explicit Deny on ListBucket for principals outside this account."
  type        = bool
  default     = true
}

# --- F-11 ------------------------------------------------------------------
variable "versioning_enabled" {
  description = "F-11. Without it, an in-place encrypt or a delete is terminal. Prerequisite for Object Lock and for F-07's pinned-versionId fix."
  type        = bool
  default     = true
}

variable "object_lock_enabled" {
  description = "13 §13.3. Forces versioning on; neither can be undone. An Object Lock bucket cannot be a server-access-log destination."
  type        = bool
  default     = false
}

variable "object_lock_mode" {
  description = "GOVERNANCE (a principal with s3:BypassGovernanceRetention can override) | COMPLIANCE (nobody can, including root — and GDPR Art.17 erasure becomes impossible until retention expires)."
  type        = string
  default     = null
  validation {
    condition     = var.object_lock_mode == null || contains(["GOVERNANCE", "COMPLIANCE"], coalesce(var.object_lock_mode, "GOVERNANCE"))
    error_message = "object_lock_mode must be GOVERNANCE, COMPLIANCE, or null."
  }
}

variable "object_lock_retention_days" {
  type    = number
  default = 30
}

# --- Encryption ------------------------------------------------------------
variable "kms_key_arn" {
  description = "null = SSE-S3 / AWS-managed (ENC-2). Non-null = the sanctioned CMK for this tier."
  type        = string
  default     = null
}

variable "bucket_key_enabled" {
  description = "13 §13.4 Level D — a cost optimization, not a security downgrade. Do not flag it as a finding."
  type        = bool
  default     = true
}

variable "enforce_sse_kms_writes" {
  description = "ENC-5. Deny PutObject lacking aws:kms, and deny any key ARN other than the sanctioned CMK."
  type        = bool
  default     = true
}

variable "deny_sse_c" {
  description = "ENC-6. Deny customer-provided keys — the one-command S3 ransomware primitive."
  type        = bool
  default     = true
}

# --- ENC-1 -----------------------------------------------------------------
variable "deny_insecure_transport" {
  description = "ENC-1. Deny when aws:SecureTransport is false."
  type        = bool
  default     = true
}

variable "minimum_tls_version" {
  description = "ENC-1. e.g. \"1.2\". null disables the version floor."
  type        = string
  default     = "1.2"
}

# --- LOG-1 -----------------------------------------------------------------
variable "access_log_bucket" {
  description = "LOG-1. Should be in a SEPARATE account so a compromised writer cannot erase its own trail. Floci is single-account — see README 'Emulation gaps'."
  type        = string
  default     = null
}

# --- P-01 / 13 §13.2 Level D ----------------------------------------------
variable "lifecycle_rules" {
  description = "Retention per prefix. noncurrent_version_expiration_days is the forensic window — write down why you chose the number."
  type = list(object({
    id                                 = string
    prefix                             = string
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
  }))
  default = []
}

# --- Named grants ----------------------------------------------------------
variable "read_principal_arns" {
  type    = list(string)
  default = []
}

variable "read_prefixes" {
  type    = list(string)
  default = [""]
}

variable "write_principal_arns" {
  description = "F-14 mitigation: a single write-only prefix, no read, no cross-prefix."
  type        = list(string)
  default     = []
}

variable "write_prefixes" {
  type    = list(string)
  default = []
}

# --- 04 §4.7 ---------------------------------------------------------------
variable "cloudfront_distribution_arn" {
  description = "Ties origin reads to one distribution. Without this condition, OAC does not close the origin to the internet."
  type        = string
  default     = null
}

variable "extra_policy_statements" {
  type = list(object({
    sid                   = string
    effect                = string
    actions               = list(string)
    resources             = list(string)
    principal_type        = string
    principal_identifiers = list(string)
  }))
  default = []
}

variable "seed_objects" {
  description = "key => content. Synthetic fixtures so the findings are demonstrable."
  type        = map(string)
  default     = {}
}
