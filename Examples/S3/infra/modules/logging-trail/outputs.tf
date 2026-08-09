output "trail_name" {
  value = local.trail_name
}

output "trail_arn" {
  value = var.use_native_trail_resource ? aws_cloudtrail.this[0].arn : local.trail_arn
}

output "data_events_enabled" {
  description = "LOG-1. Verify independently with: aws cloudtrail get-event-selectors --trail-name <name>"
  value       = var.enable_data_events
}

output "trail_bucket_name" {
  value = aws_s3_bucket.trail.id
}

output "access_log_bucket_name" {
  value = var.create_access_log_bucket ? aws_s3_bucket.access_logs[0].id : null
}

output "posture_summary" {
  value = compact([
    !var.enable_data_events ? "LOG-1 OPEN: management events only — object reads are unrecorded" : null,
    !var.create_access_log_bucket ? "LOG-1 partial: no S3 server access log destination" : null,
    !var.enable_log_file_validation ? "Trail integrity not validated" : null,
  ])
}
