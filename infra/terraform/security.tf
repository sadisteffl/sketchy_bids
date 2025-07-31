resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "foundational_best_practices" {
  depends_on = [aws_securityhub_account.this]

  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

data "aws_guardduty_detector" "this" {}

resource "aws_sns_topic" "guardduty_notifications" {
  name_prefix = "guardduty-high-severity-findings-"
  kms_master_key_id = aws_kms_key.mainkms.arn
  }

resource "aws_sns_topic_subscription" "guardduty_email_alert" {
  topic_arn = aws_sns_topic.guardduty_notifications.arn
  protocol  = "email"
  endpoint  = "sadisteffl@gmail.com"
}

resource "aws_cloudwatch_event_rule" "guardduty_high_severity_rule" {
  name_prefix = "guardduty-high-severity-rule-"
  description = "Triggers on critical or high severity GuardDuty findings."
  event_pattern = jsonencode({
    source        = ["aws.guardduty"],
    "detail-type" = ["GuardDuty Finding"],
    detail = {
      severity = [{ "numeric" : [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_severity_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_notifications.arn

}

resource "aws_sns_topic_policy" "allow_eventbridge_to_guardduty_topic" {
  arn    = aws_sns_topic.guardduty_notifications.arn
  policy = data.aws_iam_policy_document.sns_eventbridge_policy.json
}

data "aws_iam_policy_document" "sns_eventbridge_policy" {
  statement {
    sid       = "AllowEventBridgeToPublish"
    effect    = "Allow"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.guardduty_notifications.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_group" "sketchy_bids_cloudtrail_logs" {
  name_prefix       = "aws-cloudtrail-logs-"
  retention_in_days = 365
    kms_key_id = aws_kms_key.mainkms.arn
  }


resource "aws_sns_topic" "cloudtrail_notifications" {
  name_prefix = "cloudtrail-activity-notifications-"
  kms_master_key_id = aws_kms_key.mainkms.arn
  }

resource "aws_sns_topic_policy" "sketchy_bids_cloudtrail_sns_policy" {
  arn    = aws_sns_topic.cloudtrail_notifications.arn
  policy = data.aws_iam_policy_document.cloudtrail_sns_policy_doc.json
}

data "aws_iam_policy_document" "cloudtrail_sns_policy_doc" {
  statement {
    sid    = "AllowCloudTrailToPublish"
    effect = "Allow"
    actions = [
      "SNS:Publish",
    ]
    resources = [
      aws_sns_topic.cloudtrail_notifications.arn,
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_cloudtrail" "sketchy_bids" {
  name                          = "sketchy-bids-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.sketchy_bids_cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  enable_logging                = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.sketchy_bids_cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.sketchy_bids_cloudtrail_cloudwatch_role.arn
  sns_topic_name                = aws_sns_topic.cloudtrail_notifications.name

  kms_key_id = aws_kms_key.mainkey.arn

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  depends_on = [
    aws_s3_bucket_policy.sketchy_bids_cloudtrail_logs,
    aws_iam_role_policy.sketchy_bids_cloudtrail_cloudwatch_policy,
    aws_sns_topic_policy.sketchy_bids_cloudtrail_sns_policy
  ]
}

resource "aws_kms_key" "mainkey" {
  description             = "KMS key for CloudTrail logs"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to use the key",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:Encrypt"
        ],
        Resource = "*"
      }
    ]
  })
}


resource "aws_cloudwatch_metric_alarm" "sketchy_bids_cloudtrail_insight_alarm" {
  alarm_name          = "CloudTrail-Insight-Activity-Detected"
  alarm_description   = "Triggered when unusual API activity is detected by CloudTrail Insights."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "InsightEventCount"
  namespace           = "CloudTrail/Insights"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.guardduty_notifications.arn]
}

resource "aws_sns_topic" "security_notifications" {
  name_prefix = "security-event-notifications-"
    kms_master_key_id = aws_kms_key.mainkms.arn
}

resource "aws_wafv2_web_acl_association" "alb_waf_assoc" {
  resource_arn = aws_lb.sketchy_bids_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.sketchy_bids_waf.arn
}


resource "aws_wafv2_web_acl" "sketchy_bids_waf" {
  name  = "sketchy_waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-sqli-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-linux-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 50

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_inspector2_enabler" "inspector" {
  account_ids = [data.aws_caller_identity.current.account_id]
  resource_types = [
    "EC2"
  ]
}


resource "aws_s3_bucket" "sketchy_bids_config_bucket" {
  bucket = "aws-config-bucket-${data.aws_caller_identity.current.account_id}"
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.sketchy_bids_config_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck",
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.sketchy_bids_config_bucket.arn
      },
      {
        Sid    = "AWSConfigBucketDelivery",
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.sketchy_bids_config_bucket.arn}/*"
      }
    ]
  })
}


resource "aws_config_configuration_recorder" "main" {
  name     = "default"
  role_arn = aws_iam_role.config_role.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config_role" {
  name = "aws-config-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_role_attachment" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_delivery_channel" "main" {
  name           = "config_channel"
  s3_bucket_name = aws_s3_bucket.sketchy_bids_config_bucket.bucket

  depends_on = [aws_config_configuration_recorder.main]
}



resource "aws_security_group" "secretsmanager_vpce_sg" {
  name        = "secretsmanager-vpce-sg"
  description = "Security group for Secrets Manager VPC endpoint"
  vpc_id      = aws_vpc.sketchy_bids.id
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = aws_vpc.sketchy_bids.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.secretsmanager_vpce_sg.id]
}

resource "aws_security_group_rule" "allow_eks_nodes_to_secretsmanager_vpce" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.secretsmanager_vpce_sg.id
  source_security_group_id = aws_eks_cluster.sketchy_bids_cluster.vpc_config[0].cluster_security_group_id
  description              = "Allow EKS nodes to access the Secrets Manager VPC endpoint"
}


resource "aws_s3_bucket" "inspector_sbom_bucket" {
  bucket        = "inspector-sbom-ec2-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}



resource "aws_s3_bucket_policy" "inspector_sbom_bucket_policy" {
  bucket = aws_s3_bucket.inspector_sbom_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowInspectorSBOMExport",
        Effect = "Allow",
        Principal = {
          Service = "inspector2.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.inspector_sbom_bucket.arn}/*", # The "/*" is crucial.
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "alb_logs" {
  bucket = "alb-access-logs-sketchy-bids" # must be unique globally

  acl = "private"

  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
  }
}

resource "aws_kms_key" "mainkms" {
  description             = "KMS key for encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}
