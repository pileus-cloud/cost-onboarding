### AWS Script

##### Preparation
```
# Prepare aws profile for menagment aws account
# TO check it
export AWS_PROFILE=<profile-name>
aws sts get-caller-identity
```

Open file Connect2Anodot.sh and change: 
- ExternalId
- RootId (just for linked accounts)
- If we want to onboard link accounts: AnodotLinkedAccountRole="true"
  Should activate trusted access with AWS Organizations: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-activate-trusted-access.html
- If we want to onboard just managment account: AnodotLinkedAccountRole="false"

```
bash ./Connect2Anodot.sh
```

##### What will be created
``` 
Template Deploys:
- S3 bucket – named cur-<Account-ID>
- Cost and Usage Report
- IAM Role with trust policy to account 932213950603(anodot aws account id) with Externalid condition.
- IAM Role for all linked accounts (optional)
```
 
