# Look up your existing Hosted Zone (since you bought it via Console)
data "aws_route53_zone" "main" {
  name = var.domain_name
  # zone_id      = "Z04376043T34812BLBEDG" # This is here for debugging
  private_zone = false
}

# ================================================================ #
# CERTIFICATES REMOVED FOR SÃO PAULO
# ================================================================ #
# São Paulo is accessed through Tokyo's CloudFront (global entry point).
# Creating certificates for the same domains conflicts with Tokyo's
# ACM validation records. The ALB will use HTTP for internal/testing access.
# ================================================================ #

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
  name     = "${var.project_name}-flask-tg"
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

# HTTP Listener (Port 80) - São Paulo uses HTTP since it's accessed via Tokyo CloudFront
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action: DENY direct access
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Access Denied: Direct ALB access is prohibited."
      status_code  = "403"
    }
  }
}

# ================================================================ #
# HEADER VALIDATION - Only allow traffic with secret header
# ================================================================ #
# This prevents direct ALB access - only CloudFront (which adds the
# X-Custom-Header) can reach the backend.

resource "aws_lb_listener_rule" "require_header" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_app.arn
  }

  condition {
    http_header {
      http_header_name = "X-Custom-Header"
      values           = [random_password.origin_header.result]
    }
  }
}

# ================================================================ #
# Route53 Records - REMOVED FOR SÃO PAULO
# ================================================================ #
# Tokyo's CloudFront owns the domain aliases (daequanbritt.com, app.daequanbritt.com).
# São Paulo ALB is accessed directly via its DNS name for testing,
# or through Tokyo's CloudFront for production traffic.
# ================================================================ #
