# Anodot Onboarding Deployment

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
- [Files and Structure](#files-and-structure)
- [Parameters](#parameters)
- [Script Details](#script-details)
- [Troubleshooting](#troubleshooting)

## Overview
The `deploy_anodot.sh` script automates the deployment of AWS resources required for Anodot onboarding. It ensures that the necessary AWS access permissions, S3 buckets, IAM roles, and StackSets are correctly configured and deployed.

## Prerequisites
Before running the script, ensure the following:
- AWS CLI is installed and configured.
- Your AWS credentials are set up correctly (`aws configure`).
- The executing AWS account has sufficient permissions to create CloudFormation stacks, IAM roles, S3 buckets, and Lambda functions.
- AWS Organizations is enabled and the executing account is a **Payer (Management) Account**.

## Deployment Steps
1. **Fetch generated script**

2. **Make the script executable:**
   ```bash
   chmod +x deploy_anodot.sh
   ```
3. **Run the deployment script:**
   ```bash
   ./deploy_anodot.sh
   ```
   The script will:
   - Validate AWS credentials
   - Validate the Payer account
   - Validate and deploy the CloudFormation stack
   - Create necessary IAM roles and S3 buckets
   - Deploy StackSets for linked accounts

## Files and Structure

### Main Deployment Script
- **`deploy_anodot.sh`**: The main deployment script to automate onboarding.

### CloudFormation Templates
- **`anodotpayer.yaml`**: Deploys Anodot-related AWS resources for the payer account.
- **`anodotlinkedrecursive.yaml`**: Deploys StackSets to onboard linked accounts.

## Parameters
The following parameters are used in the deployment:

- **ExternalId**: A unique identifier provided by Anodot for secure role assumption.
- **CostAndUsageReport**: Boolean value (`true` or `false`) to determine if the AWS Cost and Usage Report (CUR) should be deployed.
- **CURbucket**: Boolean value (`true` or `false`) to specify whether an S3 bucket should be created for CUR storage.
- **CURbucketName**: The name of the S3 bucket used for storing the CUR data. If left empty, it defaults to `cur-<AWS_ACCOUNT_ID>`.
- **StackSetName**: The name of the AWS CloudFormation StackSet for linked accounts, defaulting to `AnodotLinkedAccount`.

## Script Details
The `deploy_anodot.sh` script consists of several key functions:
- `validate_aws_access()`: Ensures AWS credentials are valid.
- `validate_payer_account()`: Checks if the account is the Payer (Management) account.
- `validate_template()`: Validates the CloudFormation template.
- `validate_bucket_name()`: Ensures the provided S3 bucket name is valid.
- `check_bucket_exists()`: Checks if the S3 bucket already exists.
- `check_role_exists()`: Checks if the IAM role exists before deployment.
- `check_lambda_exists()`: Checks if the required Lambda function exists.
- `deploy_stack()`: Deploys the main CloudFormation stack.
- `deploy_stack_linked()`: Deploys CloudFormation StackSets for linked accounts.
- `StackSetsTrustAccess()`: Ensures StackSets trusted access is enabled.
- `check_stack_exists()`: Checks if a stack already exists before deployment.

## Troubleshooting
### Common Issues & Fixes
1. **AWS Credentials Issue:**
   - Ensure AWS CLI is configured with the correct access keys:
     ```bash
     aws configure
     ```
   - Verify credentials with:
     ```bash
     aws sts get-caller-identity
     ```

2. **CloudFormation Validation Errors:**
   - Run the validation manually:
     ```bash
     aws cloudformation validate-template --template-body file://anodotpayer.yaml
     ```

3. **S3 Bucket Name Issues:**
   - Ensure the bucket name follows AWS naming conventions (3-63 characters, lowercase, no special characters).
   
4. **IAM Role or Lambda Function Already Exists:**
   - If a role or function exists, manually delete it before re-running the script:
     ```bash
     aws iam delete-role --role-name PileusRole
     aws lambda delete-function --function-name OnboardingAnodotNotificationLambda
     ```
