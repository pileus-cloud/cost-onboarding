#!/bin/bash -e
# bash Connect2Anodot.sh ExternalId=40f3e3d3

##import externalId parameter
param=$1
key=${param%=*}
value=${param#*=}


echo $'\e[32;1m\e[0m\e[4m'
echo $'\e[32;1m\e[0m\e[4m'
echo $'\e[32;1m                           Welcome!                           \e[0m\e[4m'
echo -e "\n"

sleep 2
echo $'\e[32;1m\e[0m\e[4m'
echo $'\e[32;1m\e[0m\e[4m'
echo $'\e[32;1mLets get started with Anodot Configuration\e[0m\e[4m'
echo -e "\n"


##cloudformation deployment
echo $'\e[32;1mDeploying CloudFormation Stack Which Create Following Resources:\e[0m\e[4m'
echo -e "\n"
sleep 1
echo $'\e[32;1m##IAM Role For Anodot Access\e[0m\e[4m'
echo $'\e[32;1m###Cost And Usage Report\e[0m\e[4m'
echo $'\e[32;1m####S3 Bucket For CUR Files\e[0m\e[4m'

##stack for payer account
aws --region us-east-1 cloudformation create-stack --stack-name Anodot-Onboarding --template-body file://AnodotPayer.yaml \
                --parameters ParameterKey=$key,ParameterValue=$value --capabilities CAPABILITY_NAMED_IAM --output json

function pro {
            bar=''
                for (( x=0; x <= 100; x++ )); do
                                sleep 0.6
                                        bar="${bar}="
                                                echo -ne "$bar ${x}%\r"
                                                    done
                                                        echo -e "\n"
                                                }
 pro

echo $'\e[32;1mCloudFormation Template Deployment Completed\e[0m\e[4m'
echo -e "\n"

##get and set account id parameter
ACC_ID=$(aws sts get-caller-identity --query 'Account' --output text)

##notification file for Anodot
echo $'\e[32;1mCreating Notification File for Anodot\e[0m\e[4m'
echo -e "\n"
touch "$ACC_ID"_connect_to_pileus.txt
echo $'\e[32;1mDone!\e[0m\e[4m'
echo -e "\n"
sleep 2

##import parameters into notification file
echo -e "[DEFAULT]\n    aws_account_id = "$ACC_ID"\n    s3_invoice_bucket = cur-"$ACC_ID"\n    pileus_role_arn = arn:aws:iam::"$ACC_ID":role/AnodotRole-Onboarding\n    ">> "$ACC_ID"_connect_to_pileus.txt

##upload file to cur bucket
echo $'\e[32;1mUploading Anodot Notification File to s3 CUR Bucket\e[0m\e[4m'
aws s3 cp "$ACC_ID"_connect_to_pileus.txt  s3://cur-"$ACC_ID"
echo $'\e[32;1mNotification File Uploaded\e[0m\e[4m'
echo -e "\n"

sleep 2
echo $'\e[32;1mConfiguration Completed\e[0m\e[4m'
echo -e "\n"

##get role arn
echo $'\e[32;1mSend Following ARN to Anodot:\e[0m\e[4m'
aws iam get-role --role-name AnodotRole-Onboarding | grep Arn | awk '{print $2}'

