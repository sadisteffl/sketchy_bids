

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = ["6938fd4d9c60c1c808d947850624c9a445a9ac84"]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.sketchy_bids_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd10df6"]
}

resource "aws_iam_policy" "secretsmanager_access" {
  name        = "SecretsManagerSketchyBidsAccess"
  description = "Allows access to the SketchyBids secret in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:sketchydraw/backend-*"
      }
    ]
  })
}


resource "aws_iam_role" "k8s_sa_sketchybid" {
  name = "IRSA-SketchyBids"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:default:sa-sketchydraw"
        }
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "attach_secretsmanager_access" {
  role       = aws_iam_role.k8s_sa_sketchybid.name
  policy_arn = aws_iam_policy.secretsmanager_access.arn
}

resource "aws_iam_role" "sketchy_bids_cloudtrail_cloudwatch_role" {
  name = "cloudtrail-cloudwatch-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sketchy_bids_cloudtrail_cloudwatch_policy" {
  name = "sketchy-bids-cloudtrail-cloudwatch-policy-${random_id.suffix.hex}"
  role = aws_iam_role.sketchy_bids_cloudtrail_cloudwatch_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "CloudWatchLogsPermission",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "${aws_cloudwatch_log_group.sketchy_bids_cloudtrail_logs.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role" "github_actions_ecr_role" {
  name = "github-actions-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:sadisteffl/sketchy-bids:*"
          }
        }
      }
    ]
  })
}


resource "aws_iam_policy" "github_actions_ecr_policy" {
  name        = "GitHubActionsECRPolicy"
  description = "Policy for GitHub Actions to access ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowECRLogin",
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      {
        Sid    = "AllowECRImagePush",
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = [
          aws_ecr_repository.sketchy_bids_frontend_app.arn,
          aws_ecr_repository.sketchy_bids_backend_app.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_ecr_attachment" {
  role       = aws_iam_role.github_actions_ecr_role.name
  policy_arn = aws_iam_policy.github_actions_ecr_policy.arn
}
