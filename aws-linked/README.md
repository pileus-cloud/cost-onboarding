# Anodot AWS StackSet Management

This CloudFormation template creates a Lambda function that manages AWS CloudFormation StackSets across multiple AWS accounts in an AWS Organization. The StackSet deploys resources to onboarded accounts that are tagged with `anodot:onboarded`.

## Parameters

- **ExternalId**: (Required) External ID provided by Anodot.
- **StackSetName**: (Optional) The name of the CloudFormation StackSet. Default is `AnodotLinkedAccountTest`.

# Recursive version ( awsLinkedAccOnboardRecursive.yaml )

### Lambda Function: `GetRootIdLambda`
- **Description**: Retrieves the root ID of the AWS Organization using the `organizations:list_roots` API.
- **Runtime**: Python 3.11
- **Timeout**: 30 seconds
- **IAM Role**: The Lambda function is granted permissions to query the AWS Organizations API (`organizations:ListRoots`) via the `LambdaExecutionRole`.

### IAM Role: `LambdaExecutionRole`
- **Description**: An IAM role that allows the Lambda function to assume the necessary permissions to query the AWS Organizations API.

### Custom Resource: `GetOrganizationRootId`
- **Description**: Calls the Lambda function (`GetRootIdLambda`) to obtain the root ID of the AWS Organization. The root ID is later used to target all accounts under the organization for StackSet deployment.

### StackSet: `AnodotAccountsStackSet`
- **Description**: Creates a CloudFormation StackSet that deploys an IAM role to all accounts within the AWS Organization.
- **Target**: All accounts under the organization, identified by the root ID.
- **Template URL**: A predefined CloudFormation template hosted on S3 (`PileuseOnboardingCFT.json`) will be deployed to each account.
- **Auto Deployment**: Enabled, so any new accounts added to the organization will automatically receive the IAM role.

## Template Explanation

### Lambda for Retrieving Root ID
- **GetRootIdLambda**: This Lambda function fetches the root ID of your AWS Organization, which is necessary to target all accounts in the StackSet.

### StackSet Creation
- **AnodotAccountsStackSet**: This resource creates a StackSet that deploys the IAM role for Anodot across all accounts in the AWS Organization. The IAM role will allow Anodot to assume the role for cross-account access.

### Deployment
- The StackSet is deployed to all accounts under the organization using the root ID retrieved by the Lambda function.
- **AutoDeployment** is enabled to ensure that any new accounts added to the Organization will automatically receive the IAM role.

## Key Features
- **Automated Account Linking**: Automatically deploys the required IAM role to all accounts in the AWS Organization.
- **Auto Deployment**: Ensures new accounts in the Organization automatically receive the IAM role.
- **Customizable StackSet**: Allows customization of the StackSet name and other properties as needed.





# Version with a selection of accounts ( awsLinkedAccOnboard.yaml  )

## Resources

- **LambdaExecutionRole**: 
  - IAM role with necessary permissions for the Lambda function to manage StackSets and interact with AWS Organizations.
  
- **LambdaFunction**: 
  - Python-based Lambda function that:
    - Retrieves all accounts in the AWS Organization.
    - Filters accounts based on the `anodot:onboarded` tag.
    - Manages the CloudFormation StackSet by creating or deleting stack instances for the onboarded accounts.

- **LambdaTriggerRule**: 
  - A CloudWatch Event rule that triggers the Lambda function every hour to update the StackSet.

- **LambdaPermission**: 
  - Grants CloudWatch permission to invoke the Lambda function.

- **AnodotAccountsStackSet**: 
  - A CloudFormation StackSet that deploys resources to all onboarded accounts in the AWS Organization.

## Lambda Function Workflow

1. **Account Discovery**: 
   The Lambda function lists all accounts in the AWS Organization.
   
2. **Tag Filtering**: 
   It checks each account's tags to find those with the `anodot:onboarded` tag.
   
3. **StackSet Management**: 
   For onboarded accounts, the function manages the StackSet by creating or deleting instances as necessary.

4. **Scheduled Execution**: 
   The function is triggered every hour by a CloudWatch Event rule.



# Usage
0. StackSets Trusted Access.
  **Ensure that trusted access for CloudFormation StackSets is enabled in AWS Organizations. Use the following script to check and enable trusted access**:
```bash
#!/bin/bash
StackSetsTrustAccess() {
  # Check if CloudFormation StackSets trusted access is already enabled
  SERVICE_PRINCIPAL="member.org.stacksets.cloudformation.amazonaws.com"

  # List services with trusted access enabled
  ENABLED_SERVICES=$(aws organizations list-aws-service-access-for-organization --query 'EnabledServicePrincipals[].ServicePrincipal' --output text)

  # Check if StackSets is in the list
  if echo "$ENABLED_SERVICES" | grep -q "$SERVICE_PRINCIPAL"; then
    echo "Trusted access for CloudFormation StackSets is already enabled."
  else
    echo "Could you please enable trusted access for CloudFormation StackSets..."
    # You should activate trusted access with AWS Organizations.
    echo "https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-activate-trusted-access.html"
    exit 1

    # Enable trusted access for CloudFormation StackSets via cli
    # Does not work correctly via cli on 09/13/2024
    # aws organizations enable-aws-service-access --service-principal $SERVICE_PRINCIPAL

    # echo "Trusted access for CloudFormation StackSets has been enabled."
  fi
}
StackSetsTrustAccess
```
1. Deploy the CloudFormation template.
2. Provide the `ExternalId` from Anodot as a parameter.
```
aws --region us-east-1 cloudformation create-stack --stack-name <stack-name> --template-body file://awsLinkedAccOnboard.yaml \
 --parameters ParameterKey=ExternalId,ParameterValue=<ExternalId> \
 --capabilities CAPABILITY_NAMED_IAM --output json

```
3. The Lambda function will automatically manage the StackSet for onboarded accounts every hour.
