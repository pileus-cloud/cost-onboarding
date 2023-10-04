### AWS Script

##### Command to run the script ./Connect2Anodot.sh 
Open file Connect2Anodot.sh and change ExternalId and RootId
```
bash ./Connect2Anodot.sh
```

##### Option 1
``` 
Activate trusted access with AWS Organizations
https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-activate-trusted-access.html

Deploys the template below, creates and upload “Connect to Anodot File” to cur bucket.
CloudFormation Template: AnodotPayer.yaml

Template Deploys:
- S3 bucket – named cur-<Account-ID>
- Cost and Usage Report
- IAM Role with trust policy to account 932213950603(anodot aws account id) with Externalid condition.
- IAM Role for all linked accounts (optional)
```
 
