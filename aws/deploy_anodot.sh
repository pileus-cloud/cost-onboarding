#!/bin/bash -e

# Constants
REGION="us-east-1"
STACK_NAME="Anodot-Onboarding"
TEMPLATE_FILE="AnodotPayer.yaml"
TEMPLATE_FILE_LINKED="AnodotLinkedRecursive.yaml"

ROLE_NAME="PileusRole"
LAMBDA_NAME="OnboardingAnodotNotificationLambda"

# Parameters
ExternalId="feffdsfds"
CreateBucket="true" # value: false is not tested yet
OnboardLinkedAccounts="true"
CURbucketName="" # default: cur-<acc_id> if empty

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

# Functions

# Validate AWS Access
validate_aws_access() {
  echo -e "${CYAN}Validating AWS access credentials...${NC}"
  if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials are invalid or not configured properly.${NC}"
    echo -e "${YELLOW}Reference:${NC}"
    echo -e "${CYAN}To set up AWS CLI, run the following commands:${NC}"
    echo -e "${GREEN}  aws configure${NC}"
    echo -e "${CYAN}You will be prompted to enter your AWS Access Key, Secret Access Key, Region, and output format.${NC}"
    echo -e "${CYAN}For more details, visit: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html${NC}"
    exit 1
  fi
  echo -e "${GREEN}AWS access validation successful.${NC}"
}

# Validate if the current account is the Payer (Management) Account
validate_payer_account() {
  echo -e "${CYAN}Validating if the current account is a Payer (Management) account...${NC}"

  # Get the current account ID
  export CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

  # Fetch account details from AWS Organizations
  ACCOUNT_INFO=$(aws organizations describe-account --account-id "$CURRENT_ACCOUNT_ID" 2>/dev/null)

  # Check if account is Management
  if echo "$ACCOUNT_INFO" | grep -q '"Status": "ACTIVE"'; then
    echo -e "${GREEN}Account ID: ${CURRENT_ACCOUNT_ID} is validated as active.${NC}"
  else
    echo -e "${RED}Failed to validate the current account. Ensure it is part of AWS Organizations.${NC}"
    exit 1
  fi

  # Check if the account is a Management (Payer) account
  MGMT_ACCOUNT_ID=$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text)
  if [[ "$CURRENT_ACCOUNT_ID" == "$MGMT_ACCOUNT_ID" ]]; then
    echo -e "${GREEN}Current account is the Payer (Management) account.${NC}"
  else
    echo -e "${RED}Error: The current account (${CURRENT_ACCOUNT_ID}) is not a Payer (Management) account.${NC}"
    exit 1
  fi
}

# Validate CloudFormation template
validate_template() {
  echo -e "${CYAN}Validating CloudFormation template: ${TEMPLATE_FILE}${NC}"

  if aws cloudformation validate-template --region "$REGION" --template-body "file://$TEMPLATE_FILE" >/dev/null 2>&1; then
    echo -e "${GREEN}Template validation successful.${NC}"
  else
    echo -e "${RED}Template validation failed. Exiting.${NC}"
    exit 1
  fi
}

# Validate S3 bucket name
validate_bucket_name() {
  echo -e "${CYAN}Validating S3 bucket name: ${CURbucketName}${NC}"

  if [[ -z $CURbucketName ]]; then
    export CURbucketName="cur-${CURRENT_ACCOUNT_ID}"
  fi

  if [[ ${#CURbucketName} -lt 3 || ${#CURbucketName} -gt 63 ]]; then
    echo -e "${RED}Bucket name must be between 3 and 63 characters long. Exiting.${NC}"
    exit 1
  fi

  if ! [[ "$CURbucketName" =~ ^[a-z0-9.-]+$ ]]; then
    echo -e "${RED}Bucket name can only contain lowercase letters, numbers, periods, and hyphens. Exiting.${NC}"
    exit 1
  fi

  if [[ "$CURbucketName" =~ ^[.-] || "$CURbucketName" =~ [.-]$ ]]; then
    echo -e "${RED}Bucket name cannot start or end with a period or hyphen. Exiting.${NC}"
    exit 1
  fi

  if [[ "$CURbucketName" =~ \.\. ]]; then
    echo -e "${RED}Bucket name cannot contain consecutive periods. Exiting.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Bucket name is valid.${NC}"
}

# Check if S3 bucket already exists
check_bucket_exists() {
  echo -e "${CYAN}Checking if S3 bucket ${CURbucketName} already exists...${NC}"
  if aws s3api head-bucket --bucket "$CURbucketName" 2>/dev/null; then
    if [ $CreateBucket == "true" ]; then
      echo -e "${YELLOW}S3 bucket ${CURbucketName} already exists. Please delete the bucket or update the parameter value.${NC}"
      exit 1
    else
      echo -e "${YELLOW}S3 bucket ${CURbucketName} already exists.${NC}"
      return
    fi
  fi
  echo -e "${GREEN}S3 bucket ${CURbucketName} does not exist. Proceeding...${NC}"
}

# Check if IAM role already exists
check_role_exists() {
  echo -e "${CYAN}Checking if IAM role ${ROLE_NAME} already exists...${NC}"
  if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}IAM role ${ROLE_NAME} already exists. Please delete the role or update the template.${NC}"
    exit 1
  fi
  echo -e "${GREEN}IAM role ${ROLE_NAME} does not exist. Proceeding...${NC}"
}

# Check if Lambda function already exists
check_lambda_exists() {
  echo -e "${CYAN}Checking if Lambda function ${LAMBDA_NAME} already exists...${NC}"
  if aws lambda get-function --function-name "$LAMBDA_NAME" 2>/dev/null; then
    echo -e "${YELLOW}Lambda function ${LAMBDA_NAME} already exists. Please delete the function or update the template.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Lambda function ${LAMBDA_NAME} does not exist. Proceeding...${NC}"
}

# Deploy CloudFormation stack
deploy_stack() {
  echo -e "${CYAN}Deploying CloudFormation stack: ${STACK_NAME}${NC}"

  local parameters=(
    ParameterKey=ExternalId,ParameterValue="$ExternalId"
    ParameterKey=CostAndUsageReport,ParameterValue="true"
    ParameterKey=CURbucket,ParameterValue="$CreateBucket"
    ParameterKey=CURbucketName,ParameterValue="$CURbucketName"
  )

  aws cloudformation create-stack --region "$REGION" --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters "${parameters[@]}" \
    --capabilities CAPABILITY_NAMED_IAM > /dev/null

  echo -e "${CYAN}Stack creation initiated. Waiting for completion...${NC}"
  aws cloudformation wait stack-create-complete --region "$REGION" --stack-name "$STACK_NAME"
  echo -e "${GREEN}Stack creation completed successfully.${NC}"
}


# Deploy CloudFormation stack for linked accounts
deploy_stack_linked() {
  echo -e "${CYAN}Deploying CloudFormation stack: ${STACK_NAME}-linked-accounts${NC}"
  aws cloudformation create-stack --region "$REGION" --stack-name "${STACK_NAME}-linked-accounts" \
    --template-body "file://$TEMPLATE_FILE_LINKED" \
    --parameters ParameterKey=ExternalId,ParameterValue="$ExternalId" \
    --capabilities CAPABILITY_NAMED_IAM > /dev/null

  echo -e "${CYAN}Stack creation initiated. Waiting for completion...${NC}"
  aws cloudformation wait stack-create-complete --region "$REGION" --stack-name "${STACK_NAME}-linked-accounts"
  echo -e "${GREEN}Stack creation completed successfully.${NC}"
}

# Fetch CUR bucket name dynamically
fetch_cur_bucket_name() {
  if [ -z "$CURbucketName" ]; then
    CURbucketName=$(aws sts get-caller-identity --query 'Account' --output text)
    CURbucketName="cur-${CURbucketName}" # Default bucket name based on account ID
  fi
  export CURbucketName="$CURbucketName"
  echo -e "${CYAN}Using CUR bucket name: ${CURbucketName}${NC}"
}


# Check if StackSets trusted access is enabled
StackSetsTrustAccess() {
  echo -e "${CYAN}Checking if StackSets trusted access is enabled...${NC}"
  SERVICE_PRINCIPAL="member.org.stacksets.cloudformation.amazonaws.com"

  ENABLED_SERVICES=$(aws organizations list-aws-service-access-for-organization --query 'EnabledServicePrincipals[].ServicePrincipal' --output text)

  if echo "$ENABLED_SERVICES" | grep -q "$SERVICE_PRINCIPAL"; then
    echo -e "${GREEN}Trusted access for CloudFormation StackSets is already enabled.${NC}"
    return 0
  else
    echo -e "${RED}Error: Trusted access for CloudFormation StackSets is not enabled.${NC}"
    echo -e "${YELLOW}Please enable it manually in the AWS Management Console or using the CLI.${NC}"
    echo -e "${CYAN}For more details: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-activate-trusted-access.html${NC}"
    return 1
  fi
}

# Check if a stack already exists
check_stack_exists() {
  echo -e "${CYAN}Checking if stack $1 already exists...${NC}"
  STACK_STATUS=$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$1" 2>/dev/null | jq -r '.Stacks[0].StackStatus')

  if [[ -n "$STACK_STATUS" ]]; then
    echo -e "${YELLOW}Stack $1 already exists with status: ${STACK_STATUS}.${NC}"
    if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
      echo -e "${GREEN}No need to redeploy. Skipping stack deployment.${NC}"
      return 0
    else
      echo -e "${RED}Stack $1 is in status: ${STACK_STATUS}. Please resolve this issue before proceeding.${NC}"
      exit 1
    fi
  fi

  echo -e "${GREEN}Stack $1 does not exist. Proceeding with deployment...${NC}"
  return 1
}

# Main Execution
main() {
  echo -e "${CYAN}Starting Anodot onboarding deployment...${NC}"

  echo "-------------------------------"
  # Validate AWS Access
  validate_aws_access

  echo "-------------------------------"
  # Validate Payer account
  validate_payer_account

  if ! (check_stack_exists $STACK_NAME); then
	  echo "-------------------------------"
	  # Validate CloudFormation template
	  validate_template

	  echo "-------------------------------"
	  # Validate S3 bucket name
	  validate_bucket_name

	  echo "-------------------------------"
	  # Fetch CUR bucket name dynamically
	  fetch_cur_bucket_name

	  echo "-------------------------------"
	  # Check if S3 bucket exists
	  check_bucket_exists

	  echo "-------------------------------"
	  # Check if IAM role exists
	  check_role_exists

	  echo "-------------------------------"
	  # Check if Lambda function exists
	  check_lambda_exists

	  echo "-------------------------------"
	  # Deploy the CloudFormation stack for payer account
          deploy_stack
  fi

  echo "-------------------------------"
  # Deploy the CloudFormation stack for linked accounts
  if [[ "$OnboardLinkedAccounts" == "true" ]]; then
    if ! (check_stack_exists "${STACK_NAME}-linked-accounts"); then
      if StackSetsTrustAccess; then deploy_stack_linked; fi
    fi
  fi

  echo -e "${GREEN}Anodot onboarding deployment completed successfully!${NC}"
}

# Execute the main function
main
