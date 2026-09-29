# 1. Create the Certificate in N. Virginia
resource "aws_acm_certificate" "cert_us_east_1" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["app.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cloudfront-cert"
    Environment = var.environment
    Region      = "us-east-1"
    Purpose     = "CloudFront"
  }
}

# 2. Create DNS validation records for the us-east-1 certificate
# Note: Each ACM cert has unique validation tokens, so these won't conflict with Tokyo's records
resource "aws_route53_record" "cert_validation_us_east_1" {
  for_each = {
    for dvo in aws_acm_certificate.cert_us_east_1.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# 3. Wait for the Certificate to be Validated
resource "aws_acm_certificate_validation" "cert_validation_us_east_1" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert_us_east_1.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_us_east_1 : record.fqdn]
}
