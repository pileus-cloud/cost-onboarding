### AWS Script

##### Command to run the script ./Connect2Anodot.sh 
```
bash ./Connect2Anodot.sh ExternalId=XXXXXX
```

##### Option 1
``` 
Deploys the template below, creates and upload “Connect to Anodot File” to cur bucket.
CloudFormation Template: AnodotPayer.yaml

Template Deploys:
- S3 bucket – named cur-<Account-ID>
- Cost and Usage Report
- IAM Role with trust policy to account 932213950603(anodot aws account id) with Externalid condition.
```
 
##### Option 2 (not finished)
```
CloudFormation Template with StackSet for linked accounts: AnodotPayerOrganization.yaml

Template Deploys:
- S3 bucket – named cur-<Account-ID>
- Cost and Usage Report
- IAM Role with trust policy to account 932213950603(anodot aws account id) with Externalid condition.
- CloudFormation StackSet to all  linked accounts – with PileuseOnboardingCFT.json template

Issues:
- Solution to use only CloudFormation to create all the resources
- The creation and the upload of  “Connect to Anodot File” (don’t want to use cli\lambda in the process)
```

##### What is ExternalId
https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html
