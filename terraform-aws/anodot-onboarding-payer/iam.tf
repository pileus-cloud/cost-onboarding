# IAM Role
resource "aws_iam_role" "anodot_role" {
  name = "PileusRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::932213950603:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
}

# IAM Policy
resource "aws_iam_policy" "anodot_policy" {
  name        = "AnodotManagedPolicy"
  description = "Anodot Account Policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:Get*"
        ]
        Resource = [
          "arn:aws:s3:::cur-${data.aws_caller_identity.current.account_id}/*",
          "arn:aws:s3:::cur-${data.aws_caller_identity.current.account_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:Put*"
        ]
        Resource = [
          "arn:aws:s3:::prod-invoice-update/*",
          "arn:aws:s3:::prod-invoice-update"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "organizations:ListAccounts"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:Describe*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketVersions",
          "s3:GetBucketVersioning",
          "s3:GetLifecycleConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:ListAllMyBuckets",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "logs:DescribeLogGroups",
          "logs:GetQueryResults"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateExportTask",
          "logs:StartQuery"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/containerinsights/*/performance",
          "arn:aws:logs:*:*:log-group:/aws/containerinsights/*/performance:*",
          "arn:aws:logs:*:*:log-group:/aws/containerinsights/*/performance:*:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:Describe*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:ListFargateProfiles",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeFargateProfile",
          "eks:ListTagsForResource",
          "eks:ListUpdates",
          "eks:DescribeUpdate",
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Describe*",
          "dynamodb:List*",
          "tag:GetResources",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource",
          "ecs:DescribeClusters",
          "redshift:DescribeClusters",
          "es:ListDomainNames",
          "es:DescribeElasticsearchDomains",
          "elasticache:DescribeCacheClusters",
          "kinesis:ListStreams",
          "kinesis:DescribeStream",
          "kms:ListKeys",
          "kms:DescribeKey",
          "kms:ListResourceTags",
          "cloudTrail:DescribeTrails",
          "es:DescribeReservedInstances",
          "es:DescribeReservedElasticsearchInstances",
          "rds:DescribeReservedDBInstances",
          "elasticache:DescribeReservedCacheNodes",
          "redshift:DescribeReservedNodes",
          "savingsplans:DescribeSavingsPlans"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "account:GetAccountInformation",
          "billing:GetBillingData",
          "billing:GetBillingDetails",
          "billing:GetBillingNotifications",
          "billing:GetBillingPreferences",
          "billing:GetContractInformation",
          "billing:GetCredits",
          "billing:GetIAMAccessPreference",
          "billing:GetSellerOfRecord",
          "billing:ListBillingViews",
          "ce:DescribeNotificationSubscription",
          "ce:DescribeReport",
          "ce:GetAnomalies",
          "ce:GetAnomalyMonitors",
          "ce:GetAnomalySubscriptions",
          "ce:GetCostAndUsage",
          "ce:GetCostAndUsageWithResources",
          "ce:GetCostCategories",
          "ce:GetCostForecast",
          "ce:GetDimensionValues",
          "ce:GetPreferences",
          "ce:GetReservationCoverage",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetReservationUtilization",
          "ce:GetRightsizingRecommendation",
          "ce:GetSavingsPlansPurchaseRecommendation",
          "ce:GetSavingsPlansUtilization",
          "ce:GetSavingsPlansUtilizationDetails",
          "ce:GetSavingsPlansCoverage",
          "ce:GetTags",
          "ce:GetUsageForecast",
          "ce:ListCostAllocationTags",
          "ce:ListSavingsPlansPurchaseRecommendationGeneration",
          "consolidatedbilling:GetAccountBillingRole",
          "consolidatedbilling:ListLinkedAccounts",
          "cur:GetClassicReport",
          "cur:DescribeReportDefinitions",
          "cur:GetUsageReport",
          "cur:GetClassicReportPreferences",
          "cur:ValidateReportDestination",
          "freetier:GetFreeTierAlertPreference",
          "freetier:GetFreeTierUsage",
          "invoicing:GetInvoiceEmailDeliveryPreferences",
          "invoicing:GetInvoicePDF",
          "invoicing:ListInvoiceSummaries",
          "payments:GetPaymentInstrument",
          "payments:GetPaymentStatus",
          "payments:ListPaymentPreferences",
          "tax:GetTaxInheritance",
          "tax:GetTaxRegistrationDocument",
          "tax:ListTaxRegistrations"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "anodot_policy_attachment" {
  policy_arn = aws_iam_policy.anodot_policy.arn
  role       = aws_iam_role.anodot_role.name
}

# Create IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "OnboardingAnodotNotificationLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}