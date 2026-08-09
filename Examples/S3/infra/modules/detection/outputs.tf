output "alert_topic_arn" {
  value = aws_sns_topic.security_alerts.arn
}

output "detection_rules" {
  description = "rule name => the finding it defends."
  value       = { for k, r in aws_cloudwatch_event_rule.detection : r.name => local.detections[k].finding }
}

output "config_rule_names" {
  value = [for r in aws_config_config_rule.managed : r.name]
}

output "posture_summary" {
  value = compact([
    !var.enable_alarms ? "LOG-1 OPEN: no alarms — a log nobody reads is not a control" : null,
    !var.enable_config_rules ? "F-01 partial: no continuous verification, controls can drift after deploy" : null,
  ])
}
