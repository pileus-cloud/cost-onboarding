#!/bin/bash -e

ExternalId="abcd1234"
AnodotLinkedAccountRole="true"
RootOUId="r-sp1e"

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

    # Enable trusted access for CloudFormation StackSets
    #aws organizations enable-aws-service-access --service-principal $SERVICE_PRINCIPAL

    #echo "Trusted access for CloudFormation StackSets has been enabled."
  fi
}

# If AnodotLinkedAccountRole="true"
# You should activate trusted access with AWS Organizations.
# https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-activate-trusted-access.html
[ $AnodotLinkedAccountRole == "true" ] && StackSetsTrustAccess

aws --region us-east-1 cloudformation create-stack --stack-name Anodot-Onboarding --template-body file://AnodotPayer.yaml \
                --parameters ParameterKey=ExternalId,ParameterValue=${ExternalId} \
                             ParameterKey=RootOUId,ParameterValue=${RootOUId} \
                             ParameterKey=AnodotLinkedAccountRole,ParameterValue=${AnodotLinkedAccountRole} \
                --capabilities CAPABILITY_NAMED_IAM --output json

ACC_ID=$(aws sts get-caller-identity --query 'Account' --output text)

while !(aws --region us-east-1 s3 ls s3://cur-${ACC_ID}/aws-programmatic-access-test-object >/dev/null 2>&1); do
     echo -n "="
     sleep 0.5
done; echo; echo "Done"
