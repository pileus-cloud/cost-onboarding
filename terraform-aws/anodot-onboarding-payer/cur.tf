# Cost and Usage Report Definition
resource "aws_cur_report_definition" "anodot" {
  count = var.create_cur ? 1 : 0

  report_name                = "cur-${data.aws_caller_identity.current.account_id}"
  time_unit                 = "HOURLY"
  format                    = "textORcsv"
  compression               = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                 = aws_s3_bucket.anodot_bucket[0].id
  s3_prefix                 = "hourly"
  s3_region                 = var.aws_region
  refresh_closed_reports    = true
  report_versioning        = "CREATE_NEW_REPORT"

  depends_on = [
    aws_s3_bucket.anodot_bucket,
    aws_s3_bucket_policy.anodot_bucket_policy,
    aws_lambda_invocation.notification_lambda_run
  ]
}