#!/bin/bash

ExternalId="40f3e3d3"

# You shuold activate trusted access with AWS Organizations.
AnodotLinkedAccountRole="false"
RootOUId="r-XXXX"   # for example: "r-sp1n"

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
