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

variable "enable_alarms" {
  description = "LOG-1. false is the current-state posture: the events are recorded (maybe) but nothing fires."
  type        = bool
  default     = true
}

variable "enable_config_rules" {
  description = "F-01. Continuous verification that the control did not drift after deploy."
  type        = bool
  default     = true
}

variable "config_rules" {
  description = "Managed AWS Config rule identifier => why this threat model wants it."
  type        = map(string)
  default = {
    S3_BUCKET_PUBLIC_READ_PROHIBITED         = "F-01 — continuous verification that no bucket grants anonymous read"
    S3_BUCKET_PUBLIC_WRITE_PROHIBITED        = "F-01 — anonymous write would be worse than anonymous read"
    S3_BUCKET_VERSIONING_ENABLED             = "F-11 — versioning is the prerequisite for ransomware recovery"
    S3_BUCKET_SSL_REQUESTS_ONLY              = "ENC-1 — verify the aws:SecureTransport deny is actually present"
    S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED = "ENC-5 — default encryption present"
    S3_BUCKET_LOGGING_ENABLED                = "LOG-1 — server access logging configured"
    CLOUD_TRAIL_ENABLED                      = "LOG-1 — a trail exists at all"
    IAM_USER_NO_POLICIES_CHECK               = "F-15 — policies on users rather than roles signal long-lived credentials"
  }
}
