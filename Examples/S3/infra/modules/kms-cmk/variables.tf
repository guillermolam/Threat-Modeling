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

variable "tier" {
  description = "Sensitivity tier this key serves. 13 §13.4: a separate CMK per tier turns one catastrophic blast radius into three contained ones."
  type        = string
}

# --- ENC-2 -----------------------------------------------------------------
variable "create_cmk" {
  description = "false = stay on the AWS-managed aws/s3 key (ENC-2: no key policy can be written, which blocks ENC-3/4/5/7/8 from being mitigable)."
  type        = bool
  default     = true
}

# --- ENC-3 -----------------------------------------------------------------
variable "delegate_to_account_root" {
  description = "ENC-3. Grant kms:Decrypt to arn:aws:iam::ACCT:root, delegating authorization to IAM so any principal with kms:Decrypt in an identity policy passes Plane 2."
  type        = bool
  default     = false
}

variable "decrypt_principal_arns" {
  description = "ENC-3 mitigation: named principals only. Empty means nobody but the key admins."
  type        = list(string)
  default     = []
}

variable "cross_account_principal_arns" {
  description = "F-14 / ENC-3 crypto crossing: principals outside the account allowed to decrypt. Should be empty unless a partner key is a deliberate, reviewed decision."
  type        = list(string)
  default     = []
}

variable "key_admin_arns" {
  description = "Principals allowed kms:* on this key. Defaults to the account root when empty."
  type        = list(string)
  default     = []
}

# --- ENC-4 -----------------------------------------------------------------
variable "require_via_service" {
  description = "ENC-4. Pin the key to s3.<region>.amazonaws.com so a ciphertext blob cannot be decrypted directly through the KMS API, bypassing S3's policy and logs."
  type        = bool
  default     = true
}

variable "require_source_account" {
  description = "ENC-4. aws:SourceAccount condition — cross-account confused-deputy defence."
  type        = bool
  default     = true
}

variable "required_encryption_context" {
  description = "ENC-4. Encryption context (AAD) key/value pairs the caller must supply, binding the key to one prefix or tenant."
  type        = map(string)
  default     = {}
}

# --- ENC-7 / ENC-8 ---------------------------------------------------------
variable "deny_key_lifecycle_ops" {
  description = "ENC-7. Deny ScheduleKeyDeletion / DisableKey / DeleteImportedKeyMaterial outside break-glass. In real AWS put this in an SCP as well."
  type        = bool
  default     = true
}

variable "deny_grant_operations" {
  description = "ENC-8. Deny CreateGrant / PutKeyPolicy outside break-glass. Grants are listed separately from the key policy, so a policy review alone will not find one."
  type        = bool
  default     = true
}

variable "break_glass_arns" {
  description = "Principals exempted from the ENC-7 / ENC-8 denies. Every use should be logged and reviewed."
  type        = list(string)
  default     = []
}

# --- Rotation (13 §13.4 Level C) -------------------------------------------
variable "enable_key_rotation" {
  type    = bool
  default = true
}

variable "rotation_period_in_days" {
  description = "90..2560. Rotation limits the useful life of a STOLEN key; it does nothing against an attacker holding valid IAM permissions (13 §13.4 Level D)."
  type        = number
  default     = 365
}

variable "deletion_window_in_days" {
  type    = number
  default = 30
}
