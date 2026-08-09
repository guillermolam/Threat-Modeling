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

variable "instance_profile_name" {
  description = "Instance profile from iam-estate. This is the credential SSRF steals."
  type        = string
}

variable "imdsv2_required" {
  description = "F-13. false leaves IMDSv1 answering, which is no defence at all against a single proxied GET."
  type        = bool
  default     = true
}

variable "metadata_hop_limit" {
  description = "F-13. 1 stops a proxied request from reaching IMDS. >1 re-opens the path even under IMDSv2."
  type        = number
  default     = 1
}

variable "block_link_local_egress" {
  description = "F-13 defence in depth. NACL deny on 169.254.0.0/16. See the comment in main.tf about what this does and does not stop."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_name_filter" {
  type    = string
  default = "al2023-ami-*"
}
