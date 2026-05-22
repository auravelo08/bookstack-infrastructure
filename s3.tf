############################################
# S3 BUCKET (privé)
############################################

resource "aws_s3_bucket" "bookstack" {
  bucket = "bookstack-${var.environment}-${var.project}"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "bookstack" {
  bucket = aws_s3_bucket.bookstack.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bookstack" {
  bucket = aws_s3_bucket.bookstack.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

############################################
# CLOUDFRONT OAC (Origin Access Control)
############################################

resource "aws_cloudfront_origin_access_control" "bookstack_oac" {
  name                              = "bookstack-oac"
  description                       = "OAC for BookStack S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

############################################
# CLOUDFRONT DISTRIBUTION
############################################

resource "aws_cloudfront_distribution" "bookstack_cdn" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.bookstack.bucket_regional_domain_name
    origin_id   = "bookstack-s3"

    origin_access_control_id = aws_cloudfront_origin_access_control.bookstack_oac.id
  }

  default_cache_behavior {
    target_origin_id       = "bookstack-s3"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

############################################
# S3 BUCKET POLICY (autorise CloudFront uniquement)
############################################

resource "aws_s3_bucket_policy" "bookstack_policy" {
  bucket = aws_s3_bucket.bookstack.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.bookstack.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.bookstack_cdn.arn
          }
        }
      }
    ]
  })
}

############################################
# IAM USER POUR BOOKSTACK (upload privé)
############################################

resource "aws_iam_user" "bookstack_s3_user" {
  name = "bookstack-s3-${var.environment}"
}

resource "aws_iam_access_key" "bookstack_s3_key" {
  user = aws_iam_user.bookstack_s3_user.name
}

resource "aws_iam_user_policy" "bookstack_s3_policy" {
  name = "bookstack-s3-policy"
  user = aws_iam_user.bookstack_s3_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.bookstack.arn,
          "${aws_s3_bucket.bookstack.arn}/*"
        ]
      }
    ]
  })
}

############################################
# OUTPUTS
############################################

output "bookstack_s3_access_key" {
  value = aws_iam_access_key.bookstack_s3_key.id
}

output "bookstack_s3_secret_key" {
  value     = aws_iam_access_key.bookstack_s3_key.secret
  sensitive = true
}

output "bookstack_cloudfront_domain" {
  value = aws_cloudfront_distribution.bookstack_cdn.domain_name
}
