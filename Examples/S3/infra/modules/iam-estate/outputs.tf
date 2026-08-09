output "cicd_deploy_role_arn" {
  value = aws_iam_role.cicd_deploy.arn
}

output "app_compute_role_arn" {
  value = aws_iam_role.app_compute.arn
}

output "app_compute_instance_profile" {
  value = aws_iam_instance_profile.app_compute.name
}

output "partner_role_arn" {
  value = var.create_partner_role ? aws_iam_role.partner_write[0].arn : null
}

output "analytics_agent_role_arn" {
  value = var.create_agent_role ? aws_iam_role.analytics_agent[0].arn : null
}

output "analytics_reader_role_arn" {
  value = aws_iam_role.analytics_reader.arn
}

output "human_role_arns" {
  value = { for k, r in aws_iam_role.human : k => r.arn }
}

output "all_principal_arns" {
  description = "Everything that may legitimately touch the data — feeds the KMS key policy's named-principal list (ENC-3 mitigation)."
  value = concat(
    [aws_iam_role.app_compute.arn, aws_iam_role.analytics_reader.arn],
    var.create_agent_role ? [aws_iam_role.analytics_agent[0].arn] : [],
    [for r in aws_iam_role.human : r.arn]
  )
}

output "legacy_access_key_id" {
  description = "F-15. Present only when create_static_access_keys = true."
  value       = var.create_static_access_keys ? aws_iam_access_key.legacy_operator[0].id : null
}

output "legacy_secret_access_key" {
  value     = var.create_static_access_keys ? aws_iam_access_key.legacy_operator[0].secret : null
  sensitive = true
}

output "posture_summary" {
  value = compact([
    var.cicd_wildcard_resource ? "F-09 OPEN: deploy role Resource = *" : null,
    var.compute_role_can_decrypt ? "F-13 amplified: compute role holds kms:Decrypt" : null,
    var.partner_external_id == null && var.create_partner_role ? "F-14 OPEN: no sts:ExternalId (confused deputy)" : null,
    var.partner_cross_prefix_access ? "F-14 CRITICAL: partner role scoped to bucket/* — can read /exports/" : null,
    var.create_static_access_keys ? "F-15 OPEN: long-lived IAM access key exists" : null,
    var.agent_can_write ? "F-18 OPEN: agent holds write/delete" : null,
    var.agent_can_decrypt ? "F-18 OPEN: agent holds kms:Decrypt" : null,
    !var.separate_duties ? "F-19 OPEN: no separation of duties (session finding S6)" : null,
  ])
}
