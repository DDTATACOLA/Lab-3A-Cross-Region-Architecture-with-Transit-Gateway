# Look up your existing Hosted Zone (since you bought it via Console)
data "aws_route53_zone" "main" {
  name = var.domain_name
  # zone_id      = "Z04376043T34812BLBEDG" # This is here for debugging
  private_zone = false
}

# Request an SSL Certificate from ACM
resource "aws_acm_certificate" "apex_tokyo" {
  # Uses default provider (ap-northeast-1)
  domain_name               = var.domain_name
  subject_alternative_names = ["app.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-alb-cert"
    Environment = var.environment
    Region      = var.region
    Purpose     = "ALB"
  }
}

# The Application Load Balancer (ALB)
resource "aws_lb" "main" {
  # Industry Standard: project-env-resource
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  # Enable ALB Access Logging to S3: 1C Bonus D
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = var.alb_access_logs_prefix
    enabled = var.enable_alb_access_logs
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group for your Flask App
resource "aws_lb_target_group" "flask_app" {
  name     = "flask-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Attach your EC2 instance to the Target Group
resource "aws_lb_target_group_attachment" "flask_app" {
  target_group_arn = aws_lb_target_group.flask_app.arn
  target_id        = aws_instance.web.id
  port             = 80
}

# ALIAS Record: app.daequanbritt.com -> ALB
# This is the sign pointing users to your secure entry point.
resource "aws_route53_record" "app_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# HTTPS Listener (Port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"

  # Updated policy for enterprise deployments and secure entry patterns
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  # Use the certificate directly
  certificate_arn = aws_acm_certificate_validation.apex_cert_validation.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Access Denied: Direct ALB access is prohibited."
      status_code  = "403"
    }
  }

  # depends_on = [
  #   aws_acm_certificate_validation.cert
  # ]
}

# HTTP Redirect Listener (Port 80 -> 443)
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# gatekeeper that decides which incoming traffic is allowed to reach your backend service based on a specific "secret" header
resource "aws_lb_listener_rule" "require_header" {
  listener_arn = aws_lb_listener.https.arn

  # This rule is evaluated first. If a request matches these conditions, the ALB stops looking at other rules and executes the action.
  priority = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_app.arn
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"                      # custom header name
      values           = [random_password.origin_header.result] # custom header value
    }
  }
}

# # Create the Apex Certificate in region (us-east-2)
# resource "aws_acm_certificate" "apex_tokyo" {
#   provider          = aws
#   domain_name       = var.domain_name # daequanbritt.com
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# DNS Validation Records for Tokyo ALB Certificate
resource "aws_route53_record" "apex_validation_tokyo" {
  for_each = {
    for dvo in aws_acm_certificate.apex_tokyo.domain_validation_options : dvo.domain_name => {
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

# This tells the ALB to use this certificate when it sees a request for the apex domain via SNI
# resource "aws_lb_listener_certificate" "apex_cert" {
#   listener_arn = aws_lb_listener.https.arn
#   # Using .certificate_arn from the validation resource creates a hard dependency
#   certificate_arn = aws_acm_certificate_validation.apex_cert_validation.certificate_arn
# }

# This resource "waits" until the ACM certificate is actually Issued
resource "aws_acm_certificate_validation" "apex_cert_validation" {
  certificate_arn         = aws_acm_certificate.apex_tokyo.arn
  validation_record_fqdns = [for record in aws_route53_record.apex_validation_tokyo : record.fqdn]
}

# # This attaches your Apex certificate (daequanbritt.com) to the ALB
# resource "aws_lb_listener_certificate" "apex_sni" {
#   listener_arn    = aws_lb_listener.https.arn
#   certificate_arn = aws_acm_certificate_validation.apex_cert_validation.certificate_arn
# }

# # This attaches the apex certificate as an additional cert on the same listener
# resource "aws_lb_listener_certificate" "apex_sni_support" {
#   listener_arn = aws_lb_listener.https.arn

#   # This points to the Apex validation resource you created earlier
#   certificate_arn = aws_acm_certificate_validation.apex_cert_validation.certificate_arn
# }
