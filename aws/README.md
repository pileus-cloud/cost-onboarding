# Overview Anodot Onboarding script

The script automates the deployment of AWS CloudFormation stacks, performing tasks such as validation, resource checks, and stack creation. Below is a detailed explanation of each section and its purpose.

---

## Script Steps

### 1. **Initialize Constants and Variables**

The script defines constants like AWS region, stack names, and template file paths:
```bash
REGION="us-east-1"
STACK_NAME="Anodot-Onboarding"
TEMPLATE_FILE="AnodotPayer.yaml"
TEMPLATE_FILE_LINKED="AnodotLinkedRecursive.yaml"
```
Additional variables include:
- `ROLE_NAME` (IAM role name)
- `LAMBDA_NAME` (Lambda function name)
- Parameters like `ExternalId`, `CreateBucket`, and `OnboardLinkedAccounts`.

---

### 2. **Validate AWS Access**

Checks if the AWS CLI is configured with valid credentials:
```bash
validate_aws_access() {
  if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "AWS credentials are invalid or not configured."
    exit 1
  fi
  echo "AWS access validation successful."
}
```

---

### 3. **Validate Payer Account**

Verifies that the script is being run from the Payer (Management) account:
```bash
validate_payer_account() {
  CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
  MGMT_ACCOUNT_ID=$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text)

  if [[ "$CURRENT_ACCOUNT_ID" != "$MGMT_ACCOUNT_ID" ]]; then
    echo "Error: Current account is not the Payer account."
    exit 1
  fi
  echo "Validated as Payer account."
}
```

---

### 4. **Validate CloudFormation Template**

Ensures the CloudFormation template is syntactically correct:
```bash
validate_template() {
  aws cloudformation validate-template --region "$REGION" --template-body "file://$TEMPLATE_FILE" || {
    echo "Template validation failed."
    exit 1
  }
  echo "Template validation successful."
}
```

---

### 5. **Validate and Check Resources**

#### a. **S3 Bucket Name**
Validates the naming rules for the S3 bucket:
```bash
validate_bucket_name() {
  if [[ -z "$CURbucketName" ]]; then
    CURbucketName="cur-${CURRENT_ACCOUNT_ID}"
  fi
  # Check naming constraints...
}
```

#### b. **Check Existing Resources**
- **S3 Bucket**:
  ```bash
  check_bucket_exists() {
    aws s3api head-bucket --bucket "$CURbucketName" 2>/dev/null || echo "Bucket does not exist."
  }
  ```
- **IAM Role**:
  ```bash
  check_role_exists() {
    aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null || echo "Role does not exist."
  }
  ```
- **Lambda Function**:
  ```bash
  check_lambda_exists() {
    aws lambda get-function --function-name "$LAMBDA_NAME" 2>/dev/null || echo "Lambda does not exist."
  }
  ```

---

### 6. **Deploy CloudFormation Stack**

Creates or updates the CloudFormation stack for the Payer account:
```bash
deploy_stack() {
  aws cloudformation create-stack \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters ParameterKey=ExternalId,ParameterValue="$ExternalId" \
    --capabilities CAPABILITY_NAMED_IAM
  aws cloudformation wait stack-create-complete --region "$REGION" --stack-name "$STACK_NAME"
}
```

---

### 7. **Deploy Linked Accounts Stack**

Deploys the secondary stack for linked accounts:
```bash
deploy_stack_linked() {
  aws cloudformation create-stack \
    --region "$REGION" \
    --stack-name "${STACK_NAME}-linked-accounts" \
    --template-body "file://$TEMPLATE_FILE_LINKED" \
    --parameters ParameterKey=ExternalId,ParameterValue="$ExternalId" \
    --capabilities CAPABILITY_NAMED_IAM
  aws cloudformation wait stack-create-complete --region "$REGION" --stack-name "${STACK_NAME}-linked-accounts"
}
```

---

### 8. **Main Execution**

The main function orchestrates the entire process:
```bash
main() {
  validate_aws_access
  validate_payer_account
  if ! (check_stack_exists $STACK_NAME); then
    validate_template
    validate_bucket_name
    check_bucket_exists
    check_role_exists
    check_lambda_exists
    deploy_stack
  fi
  if [[ "$OnboardLinkedAccounts" == "true" ]]; then
    if ! (check_stack_exists "${STACK_NAME}-linked-accounts"); then
      deploy_stack_linked
    fi
  fi
  echo "Deployment completed successfully!"
}

main
```

---

## Summary

The `deploy_anodot.sh` script is a comprehensive automation tool for deploying CloudFormation stacks. It includes:
- Validation steps for credentials, accounts, and resources.
- Robust error handling for common issues.
- Dynamic support for linked accounts and optional parameters.

This analysis outlines the purpose and functionality of each script section to facilitate understanding and further customization.

