# ================================================================ #
# CLOUDFRONT REMOVED FOR SÃO PAULO
# ================================================================ #
# São Paulo uses Tokyo's CloudFront as the global entry point.
# This file is intentionally empty/commented out.
#
# The architecture uses ONE global CloudFront distribution (in Tokyo)
# that routes to regional ALBs as needed.
# ================================================================ #

# resource "aws_cloudfront_distribution" "main" {
#   # Removed - São Paulo doesn't need its own CloudFront
#   # Tokyo's CloudFront serves as the global entry point
# }

# Keeping the data source as it may be referenced elsewhere but won't cause errors
# data "aws_cloudfront_origin_request_policy" "managed_cors" {
#   name = "Managed-CORS-S3Origin"
# }
