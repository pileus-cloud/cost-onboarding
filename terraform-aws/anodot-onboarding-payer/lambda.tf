
# IAM policy for the Lambda role
resource "aws_iam_role_policy" "lambda_policy" {
  name = "OnboardingAnodotNotificationLambdaPolicy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::cur-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::cur-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:DeleteFunction"
        ]
        Resource = [
          "arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:OnboardingAnodotNotificationLambda"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Create a ZIP file containing the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content = <<EOF
import boto3
from pprint import pprint
import pathlib
import os

def main(event, context):
    ########create file########
    ACC_ID = os.environ.get('ACC_ID')
    file_path = ('/tmp/'+ACC_ID+'_connect_to_pileus.txt')
    file = open(file_path, 'w')
    file.write('[DEFAULT]\n')
    file.write('    aws_account_id = '+ACC_ID+'\n')
    file.write('    s3_invoice_bucket = cur-'+ACC_ID+'\n')
    file.write('    pileus_role_arn = arn:aws:iam::'+ACC_ID+':role/PileusRole\n    ')
    file.close()

    ########upload file########
    s3 = boto3.client("s3")
    bucket_name = 'cur-'+ACC_ID
    object_name = ACC_ID+"_connect_to_pileus.txt"
    file_name = os.path.join('/tmp', ACC_ID+'_connect_to_pileus.txt')
    response = s3.upload_file(file_name, bucket_name, object_name)
    pprint(response)  # prints None

    ########delete function########
    delete_lambda_function()
    return {
        'statusCode': 200,
        'body': 'Function executed successfully'
    }

def delete_lambda_function():
    function_name = os.environ['FunctionName']
    client = boto3.client('lambda')
    client.delete_function(FunctionName=function_name)
EOF
    filename = "index.py"
  }
}

# Create the Lambda function
resource "aws_lambda_function" "anodot_notification" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "OnboardingAnodotNotificationLambda"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.main"
  runtime         = "python3.13"
  timeout         = 120

  environment {
    variables = {
      ACC_ID       = data.aws_caller_identity.current.account_id
      FunctionName = "OnboardingAnodotNotificationLambda"
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_s3_bucket.anodot_bucket  # Assuming you have this resource defined elsewhere
  ]
}

resource "aws_lambda_invocation" "notification_lambda_run" {
  count = var.trigger_lambda ? 1 : 0
  
  function_name = aws_lambda_function.anodot_notification.function_name
  
  input = ""

  depends_on = [aws_lambda_function.anodot_notification]
}

# Optional: Add CloudWatch Log Group with retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.anodot_notification.function_name}"
  retention_in_days = 14  # Adjust retention period as needed
}

