
resource "aws_iam_policy" "permissions_boundary_example" {
  name        = "MyCompany-Permissions-Boundary"
  path        = "/"
  description = "Sets the maximum permissions for developer and service roles."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        # --- GENERAL GUARDRAILS ---
        "Sid" : "DenyPrivilegeEscalation",
        "Effect" : "Deny",
        "Action" : [
          "iam:CreatePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:DeletePolicy",
          "iam:DeleteRolePermissionsBoundary",
          "iam:CreateUser",
          "iam:CreateRole"
        ],
        "Resource" : [
          "arn:aws:iam::123456789012:policy/MyCompany-Permissions-Boundary",
          "arn:aws:iam::123456789012:role/*"
        ]
      },
      {
        "Sid" : "AllowLimitedServiceActions",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",

          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",

          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "iam:PassRole"
        ],
        "Resource" : [
          "arn:aws:s3:::my-company-app-data",
          "arn:aws:s3:::my-company-app-data/*",
          "arn:aws:s3:::my-company-logs",
          "arn:aws:s3:::my-company-logs/*",

          "arn:aws:iam::123456789012:instance/*",

          "arn:aws:logs:*:123456789012:log-group:/my-app/*:*"
        ],
        "Condition" : {
          "StringEquals" : {
            "ec2:ResourceTag/Project" : "WebAppV1"
          },
          "StringEquals" : {
            "iam:PassedToService" : "ec2.amazonaws.com"
          }
        }
      }
    ]
  })
}

output "permissions_boundary_arn" {
  value       = aws_iam_policy.permissions_boundary_example.arn
  description = "The ARN of the created permissions boundary policy."
}