# The following NEED to have a value passed (no default)
variable "external_id" {
  description = "External ID provided by Anodot"
  type        = string
}

# Data source for current account ID
data "aws_caller_identity" "current" {}

# The following all have defaults set:
variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"  # This should always be us-east-1 unless testing
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "deploy_cur" {
  description = "Deploy Cost and Usage Report"
  type        = bool
  default     = true
}

variable "deploy_cur_bucket" {
  description = "Deploy S3 Bucket for CUR"
  type        = bool
  default     = true
}

variable "trigger_lambda" {
  description = "Whether to trigger the Lambda function"
  type        = bool
  default     = true
}

# Variable for conditional creation
variable "create_cur" {
  description = "Whether to create the Cost and Usage Report"
  type        = bool
  default     = true
}