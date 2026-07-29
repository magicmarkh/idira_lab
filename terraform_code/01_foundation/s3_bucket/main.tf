resource "aws_s3_bucket" "secure_bucket" {
  bucket = var.bucket_name

  tags = {
    Name  = var.bucket_name
    Owner = var.asset_owner_name
  }
}
