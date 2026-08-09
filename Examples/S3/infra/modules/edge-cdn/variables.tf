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

variable "origin_bucket_name" { type = string }
variable "origin_bucket_domain_name" { type = string }

variable "enable_oac" {
  description = "04 §4.7. Necessary but not sufficient — the bucket policy must also condition on this distribution's ARN."
  type        = bool
  default     = true
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "waf_rate_limit" {
  description = "Requests per 5 minutes per IP. The control that makes F-03 enumeration slow enough to notice."
  type        = number
  default     = 2000
}

variable "separate_ugc_behavior" {
  description = "04 §4.12. false routes /avatars/* through the default behaviour — same caching, same absent signed-URL validation, as /public/*."
  type        = bool
  default     = true
}
