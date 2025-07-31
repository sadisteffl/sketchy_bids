resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "sketchy_bids_cloudtrail_logs" {
  bucket = "sketchy-bids-cloudtrail-logs-${random_id.suffix.hex}"

  force_destroy = false
}


resource "aws_s3_bucket_public_access_block" "sketchy_bids_cloudtrail_logs" {
  bucket = aws_s3_bucket.sketchy_bids_cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "sketchy_bids_cloudtrail_logs" {
  bucket = aws_s3_bucket.sketchy_bids_cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" },
        Action    = "s3:GetBucketAcl",
        Resource  = aws_s3_bucket.sketchy_bids_cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.sketchy_bids_cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "sketchy_bids_mongodb_backup" {
  bucket = "sketchy-bids-mongodb-backup-${random_id.suffix.hex}"
}


resource "aws_s3_bucket_public_access_block" "sketchy_bids_mongodb_backup" {
  bucket = aws_s3_bucket.sketchy_bids_mongodb_backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "sketchy_bids_mongodb_backup_public_policy" {
  bucket = aws_s3_bucket.sketchy_bids_mongodb_backup.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:ListBucket",
        Resource  = aws_s3_bucket.sketchy_bids_mongodb_backup.arn
      },
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.sketchy_bids_mongodb_backup.arn}/*"
      }
    ]
  })
}


resource "aws_s3_bucket" "sketchy_bids_config_logs" {
  bucket = "sketchy-bids-config-logs-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "sketchy_bids_config_logs" {
  bucket = aws_s3_bucket.sketchy_bids_config_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
