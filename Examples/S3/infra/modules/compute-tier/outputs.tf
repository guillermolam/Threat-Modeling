output "instance_id" {
  value = aws_instance.app.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_ip" {
  value = aws_instance.app.private_ip
}

output "imds_posture" {
  value = "http_tokens=${var.imdsv2_required ? "required" : "optional"} hop_limit=${var.metadata_hop_limit}"
}

output "posture_summary" {
  value = compact([
    !var.imdsv2_required ? "F-13 OPEN: IMDSv1 enabled — a single proxied GET returns role credentials" : null,
    var.metadata_hop_limit > 1 ? "F-13 OPEN: metadata hop limit ${var.metadata_hop_limit} — a proxied request can still reach IMDS" : null,
    !var.block_link_local_egress ? "F-13 partial: no NACL deny on 169.254.0.0/16" : null,
  ])
}
