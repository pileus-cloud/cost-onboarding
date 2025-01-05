
output "s3_bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.anodot_bucket[0].id
}

output "s3_bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.anodot_bucket[0].arn
}

# Outputs
output "lambda_function_arn" {
  value = aws_lambda_function.anodot_notification.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.anodot_notification.function_name
}

# Outputs
output "anodot_role_arn" {
  description = "Anodot Role ARN"
  value       = aws_iam_role.anodot_role.arn
}

output "anodot_policy_arn" {
  value = aws_iam_policy.anodot_policy.arn
}

# Output the report definition ARN
output "cur_report_arn" {
  description = "ARN of the Cost and Usage Report"
  value       = var.create_cur ? aws_cur_report_definition.anodot[0].arn : null
}