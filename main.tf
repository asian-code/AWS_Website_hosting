provider "aws" {
  region = "us-east-1"
}
terraform {
  backend "s3" {
    bucket         = "ericn-bucket"
    key            = "env/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
  }
}
# resource "aws_vpc" "myvpc" {
#   cidr_block = "10.0.0.0/16"
# }

#region create s3 bucket, turn off block public access, readonly policy, enable static hosting
resource "aws_s3_bucket" "mys3" {
  bucket = "en-tf-website"
  tags = {
    Name    = "MyS3"
    Purpose = "Host static website"
  }
}
resource "aws_s3_bucket_public_access_block" "publicaccess" {
  bucket = aws_s3_bucket.mys3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_website_configuration" "webconfig" {
  bucket = aws_s3_bucket.mys3.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
  routing_rule {
    condition {
      key_prefix_equals = "img/"
    }
    redirect {
      replace_key_prefix_with = "images/"
    }
  }
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.mys3.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.mys3.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.mys3.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
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

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${aws_s3_bucket.mys3.id}"
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.mys3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.mys3.arn}/*"
      }
    ]
  })
}
#endregion