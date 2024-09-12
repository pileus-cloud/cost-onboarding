# Anodot AWS StackSet Management

This CloudFormation template creates a Lambda function that manages AWS CloudFormation StackSets across multiple AWS accounts in an AWS Organization. The StackSet deploys resources to onboarded accounts that are tagged with `anodot:onboarded`.

## Parameters

- **ExternalId**: (Required) External ID provided by Anodot.
- **StackSetName**: (Optional) The name of the CloudFormation StackSet. Default is `AnodotLinkedAccountTest`.

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

## Usage

1. Deploy the CloudFormation template.
2. Provide the `ExternalId` from Anodot as a parameter.
```
aws --region us-east-1 cloudformation create-stack --stack-name <stack-name> --template-body file://awsLinkedAccOnboard.yaml \
 --parameters ParameterKey=ExternalId,ParameterValue=<ExternalId> \
 --capabilities CAPABILITY_NAMED_IAM --output json

```
3. The Lambda function will automatically manage the StackSet for onboarded accounts every hour.
