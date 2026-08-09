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

variable "use_native_trail_resource" {
  description = "true = aws_cloudtrail (correct for real AWS). false = the same trail via the CLI, because Floci does not implement cloudtrail:ListTags and the provider reads tags on every refresh."
  type        = bool
  default     = false
}

variable "enable_data_events" {
  description = "LOG-1. false records only management events — the console says 'CloudTrail: enabled' while every object read goes unrecorded."
  type        = bool
  default     = true
}

variable "data_event_bucket_arns" {
  description = "Buckets to record object-level access for. Empty = all S3 objects in the account."
  type        = list(string)
  default     = []
}

variable "create_access_log_bucket" {
  description = "Separate destination for S3 server access logs. Must never carry Object Lock (13 §13.3 Level D)."
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  type    = bool
  default = true
}

variable "multi_region" {
  type    = bool
  default = false
}

variable "enable_cloudwatch_logs" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  description = "13 §13.2 Level D — the forensic window. Write down why you chose the number."
  type        = number
  default     = 90
}

variable "break_glass_arns" {
  type    = list(string)
  default = []
}
