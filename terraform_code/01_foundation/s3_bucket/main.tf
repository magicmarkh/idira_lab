resource "aws_s3_bucket" "secure_bucket" {
  bucket = var.bucket_name

  tags = {
    Name  = var.bucket_name
    Owner = var.asset_owner_name
  }

  # This bucket doubles as the shared Terraform state store (see backend.tf in
  # each layer). Guard against a stray `terraform destroy` deleting the state
  # store out from under every layer. To intentionally remove the bucket, drop
  # this block (or `terraform state rm`) first.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning: required so a corrupt/partial state write can be rolled back.
resource "aws_s3_bucket_versioning" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State is private — block all public access.
resource "aws_s3_bucket_public_access_block" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access allowlist: deny every S3 request that is neither from an approved public
# IP (var.state_allowed_ips, e.g. the laptop / a NAT EIP) nor routed through the
# VPC's S3 gateway endpoint (var.state_vpc_endpoint_id, used by in-VPC hosts).
#
# LOCKOUT RECOVERY: this Deny applies to every principal, including the account
# root. If you edit yourself out of the allowlist, fix it from an already-allowed
# IP (or the in-VPC host) with:
#   aws s3api delete-bucket-policy --bucket <bucket>
# then re-apply this layer.
resource "aws_s3_bucket_policy" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  # Ensure public-access-block is settled before attaching a policy.
  depends_on = [aws_s3_bucket_public_access_block.secure_bucket]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnlessAllowedIpOrVpce"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.secure_bucket.arn,
          "${aws_s3_bucket.secure_bucket.arn}/*",
        ]
        Condition = {
          # Not from an allowed source IP...
          NotIpAddress = {
            "aws:SourceIp" = var.state_allowed_ips
          }
          # ...and not through the allowed VPC endpoint...
          StringNotEquals = {
            "aws:SourceVpce" = var.state_vpc_endpoint_id
          }
          # ...and not an AWS service acting on your behalf.
          Bool = {
            "aws:ViaAWSService" = "false"
          }
        }
      },
    ]
  })
}
