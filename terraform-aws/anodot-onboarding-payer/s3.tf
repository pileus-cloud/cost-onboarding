# S3 Bucket
resource "aws_s3_bucket" "anodot_bucket" {
  count         = var.deploy_cur_bucket ? 1 : 0
  bucket        = "cur-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = {
    Purpose = "Anodot CUR Reports"
  }

}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "anodot_bucket_versioning" {
  bucket = aws_s3_bucket.anodot_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "anodot_bucket_public_access_block" {
  bucket = aws_s3_bucket.anodot_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "anodot_bucket_encryption" {
  bucket = aws_s3_bucket.anodot_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Notification for SNS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.anodot_bucket[0].id

  topic {
    topic_arn = "arn:aws:sns:${var.aws_region}:932213950603:prod-new-invoice-upload"
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_s3_bucket_policy.anodot_bucket_policy]
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "anodot_bucket_policy" {
  bucket = aws_s3_bucket.anodot_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSBillingDeliveryPermission"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy"
        ]
        Resource = aws_s3_bucket.anodot_bucket[0].arn
      },
      {
        Sid    = "AWSBillingWritePermission"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.anodot_bucket[0].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.anodot_bucket_public_access_block]
}