output "alb_arn" {
  value = aws_lb.internal.arn
}

output "alb_dns_name" {
  value = aws_lb.internal.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.this.arn
}

output "acm_validation_records" {
  value = aws_acm_certificate.this.domain_validation_options
}
