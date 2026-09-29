# ================================================================ #
# US-EAST-1 CERTIFICATE REMOVED FOR SÃO PAULO
# ================================================================ #
# This certificate was only needed for CloudFront.
# Since São Paulo uses Tokyo's CloudFront as the global entry point,
# this certificate is not needed.
# ================================================================ #

# resource "aws_acm_certificate" "cert_us_east_1" {
#   provider                  = aws.us_east_1
#   domain_name               = var.domain_name
#   validation_method         = "DNS"
#   subject_alternative_names = ["app.${var.domain_name}"]
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_route53_record" "cert_validation" { ... }
# resource "aws_acm_certificate_validation" "cert_validation" { ... }
