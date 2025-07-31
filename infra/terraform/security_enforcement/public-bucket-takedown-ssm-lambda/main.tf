# For the purposes of this demo I didnt include the function because I didnt want it to take down my buckets 

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Specify your desired AWS region
}

resource "aws_iam_role" "s3_remediation_lambda_role" {
  name = "s3-remediation-lambda-role"

    vpc_config {
    subnet_ids         = [aws_subnet.private1.id, aws_subnet.private2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

    tracing_config {
    mode = "Active" # "Active" traces all requests; "PassThrough" only if the request has a tracing header
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_remediation_lambda_policy" {
  name        = "s3-remediation-lambda-policy"
  description = "Policy for the S3 remediation Lambda function"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = "ssm:StartAutomationExecution",
        Resource = "arn:aws:ssm:us-east-1:296062560614:automation-definition/S3-RemediatePublicBucket*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_remediation_lambda_policy_attachment" {
  role       = aws_iam_role.s3_remediation_lambda_role.name
  policy_arn = aws_iam_policy.s3_remediation_lambda_policy.arn
}


resource "aws_lambda_function" "s3_remediation_lambda" {
  filename         = "s3_remediation_lambda.zip"
  function_name    = "s3-remediation-lambda"
  role             = aws_iam_role.s3_remediation_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"

  source_code_hash = filebase64sha256("s3_remediation_lambda.zip")
    allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.lambda_signing_profile.arn
    ]
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.s3_remediation_lambda_dlq.arn
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce" 
  }
}

    vpc_config {
    subnet_ids         = [aws_subnet.private1.id, aws_subnet.private2.id]   # Update with your actual subnet IDs
    security_group_ids = [aws_security_group.lambda_sg.id]                  # Update with your Lambda security group
  }
    tracing_config {
    mode = "Active"
  }
kms_master_key_id = aws_kms_key.mainkms.arn

reserved_concurrent_executions = 5

  environment {
    variables = {
      SSM_DOCUMENT_NAME = aws_ssm_document.s3_remediation_document.name
    }
  }
}



resource "aws_iam_role" "s3_remediation_ssm_role" {
  name = "s3-remediation-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_remediation_ssm_policy" {
  name        = "s3-remediation-ssm-policy"
  description = "Policy for the S3 remediation SSM document"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketAcl"
        ],
        Resource = "arn:aws:s3:::test-public-random3214124" 
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_remediation_ssm_policy_attachment" {
  role       = aws_iam_role.s3_remediation_ssm_role.name
  policy_arn = aws_iam_policy.s3_remediation_ssm_policy.arn
}

resource "aws_ssm_document" "s3_remediation_document" {
  name          = "S3-RemediatePublicBucket"
  document_type = "Automation"
  content = jsonencode({
    "description" : "Remediates a public S3 bucket by setting Block Public Access and a private ACL.",
    "schemaVersion" : "0.3",
    "assumeRole" : aws_iam_role.s3_remediation_ssm_role.arn,
    "parameters" : {
      "BucketName" : {
        "type" : "String",
        "description" : "The name of the S3 bucket to remediate."
      }
    },
    "mainSteps" : [
      {
        "name" : "BlockPublicAccess",
        "action" : "aws:executeAwsApi",
        "inputs" : {
          "Service" : "s3",
          "Api" : "PutPublicAccessBlock",
          "Bucket" : "{{ BucketName }}",
          "PublicAccessBlockConfiguration" : {
            "BlockPublicAcls" : true,
            "IgnorePublicAcls" : true,
            "BlockPublicPolicy" : true,
            "RestrictPublicBuckets" : true
          }
        }
      },
      {
        "name" : "SetPrivateAcl",
        "action" : "aws:executeAwsApi",
        "inputs" : {
          "Service" : "s3",
          "Api" : "PutBucketAcl",
          "Bucket" : "{{ BucketName }}",
          "ACL" : "private"
        }
      }
    ]
  })
}

