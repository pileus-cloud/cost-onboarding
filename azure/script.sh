#!/usr/bin/env bash

# Defaults
#export default_subs_id=""
export default_billing_account_id=""
export default_appregname="AnodotApp"
export default_resource_group="AnodotResourceGroup"
export default_container_name="anodotcontainer"
export default_storage_account_name="anodotblob1234"
export default_export_name="Export"
export default_directory_field="reports"

# Display a banner

# Create log file
LOG_FILE="/tmp/azure-onboarding-$(date +%F).log"
exec > >(tee -a ${LOG_FILE}) 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "
     /\                   | |     | |  
    /  \   _ __   ___   __| | ___ | |_ 
   / /\ \ | '_ \ / _ \ / _\` |/ _ \| __|
  / ____ \| | | | (_) | (_| | (_) | |_ 
 /_/    \_\_| |_|\___/ \__,_|\___/ \__|"

echo -e "\n AI Business Analytics Platform"


echo -e "\n Welcome to our automated onboarding process. This streamlined procedure encompasses the following steps:
          1. Verify necessary permissions.
          2. Create a Blob Storage container and schedule an export process to transfer files.
          3. Automatically register the application and assign appropriate roles, including Azure Blob Storage Reader and Azure Monitoring Reader.
          4. Generate a client secret for the application.
 We have invested significant effort to minimize security risks and reduce our digital footprint, ensuring a reliable and professional experience for our users."
sleep 2

echo -e "${BLUE}Checking if az has been installed...${NC}"

if (! az version);then
  echo -e "${RED}Could you please install az (azure cli)${NC}"
  exit 1
fi
echo "---"

# Authenticate the user and retrieve the subscription ID
az config set extension.use_dynamic_install=yes_without_prompt >/dev/null 2>&1

az login --query  "[0].user.name" --output tsv 2>/dev/null


#-------------------------------
### CHECKS
#-------------------------------

# Set the length of the loading bar
BAR_LENGTH=50

# Set the character used for the loading bar
BAR_CHAR="▓"

# Define the print_progress_bar function
print_progress_bar() {
  local filled=""
  local empty=""
  local progress_bar_width=$BAR_LENGTH

  for ((i = 0; i < $1; i++)); do
    filled+="$BAR_CHAR"
  done

  for ((i = 0; i < $((progress_bar_width - $1)); i++)); do
    empty+=" "
  done

  printf "|%-*s|" "$progress_bar_width" "$filled$empty"
}

# Define the loading function
loading() {
  local duration=$1
  local sleep_duration=0.1
  local max_iterations=$((duration * 10))
  local iteration=0

  while [ $iteration -lt $max_iterations ]; do
    printf "\r%s" "$(print_progress_bar $((iteration * BAR_LENGTH / max_iterations)))"
    sleep $sleep_duration
    iteration=$((iteration + 1))
  done

  printf "\n"
}


######## check if the user has owner permission on  subscription level
echo "Checking if the user has owner permission on the subscription level..."
loading 1

role=$(az role assignment list --include-classic-administrators --query "[?principalName=='$(az account show --query 'user.name' -o tsv)' && roleDefinitionName=='Owner'].principalName" -o tsv)

if [[ -z "$role" ]]; then
  echo -e "${RED}The logged-in user does not have 'Owner' permission on this subscription${NC}"
  exit 1
else
  echo -e "${GREEN}The logged-in user has 'Owner' permission on this subscription${NC}"
fi
echo "---"

########### check if the user has global or user administrator permission
echo "Checking if the user has global or user administrator permission..."
loading 1

if az role assignment list --include-classic-administrators --query "[?principalName=='$(az account show --query 'user.name' -o tsv)' && (roleDefinitionName=='Global administrator' || roleDefinitionName=='User administrator')]" | grep -q .; then
  echo -e "${GREEN}The logged-in user has 'Global administrator' or 'User administrator' role on this subscription${NC}"
else
  echo -e "${RED}The logged-in user does not have 'Global administrator' or 'User administrator' role on this subscription${NC}"
  exit 1
fi
echo "---"

################# check if the user has Billing Reader role assigned
echo "Checking if the user has Billing Reader role assigned..."
loading 1

if az role assignment list --all --query "[?roleDefinitionName=='Billing Reader' && principalName=='$(az account show --query user.name -o tsv)']" --output tsv | grep -q "Billing Reader"; then
  echo -e "${GREEN}User has Billing Reader role assigned${NC}"
else
  echo -e "${RED}User does not have Billing Reader role assigned${NC}"
  exit 1
fi
echo "---"

###################### check if the user has Monitoring Reader role assigned
echo "Checking if the user has Monitoring Reader role assigned..."
loading 1

if az role assignment list --all --query "[?roleDefinitionName=='Monitoring Reader' && principalName=='$(az account show --query user.name -o tsv)']" | grep -q .
then
  echo -e "${GREEN}User has Monitoring Reader role assigned${NC}"
else
  echo -e "${RED}User does not have Monitoring Reader role assigned${NC}"
  exit 1
fi
echo "---"

echo -e "${GREEN}All checks completed.${NC}"
echo "---"


echo -e "${BLUE}Available subscriptions:${NC}"
az account list --query '[].{name:name,id:id}' --output tsv
echo "---"

############################################
#-------------------------------
### RESOURCE GROUP SELECTION OR CREATION
#-------------------------------
############################################

# Get the list of resource groups
resource_groups=($(az group list --query '[].name' -o tsv))

default_subs_id=$(az account list  --output tsv | grep "True" | awk '{print$3}' | head -1)

#
read -e -p "$(echo -e "${BLUE}Enter the desired subscription id:${NC} ")" -i "$default_subs_id" SUBSCRIPTION_ID
az account set -s $SUBSCRIPTION_ID
#

az billing account list --query '[].{displayName:displayName,name:name}' --output tsv 2>/dev/null
billing_account_ids=($(az billing account list --query '[].name' -o tsv 2>/dev/null))
read -e -p "$(echo -e "${BLUE}Enter the desired billing account id:${NC} ")" -i "${default_billing_account_id}" billing_account_id

#
echo "---"
echo -e "${BLUE}If any resource does not exist it will be created.${NC}"
echo "---"

read -e -p "$(echo -e "${BLUE}Enter the desired application_name:${NC} ")" -i "${default_appregname}" appregname

read -e -p "$(echo -e "${BLUE}Enter the desired resource group: ${NC} ")" -i "${default_resource_group}" resource_group

read -e -p "$(echo -e "${BLUE}Enter the desired container name: ${NC} ")" -i "${default_container_name}" CONTAINER_NAME

echo -e "${GREEN}Storage account name must use numbers and lower-case letters only.${NC}"
read -e -p "$(echo -e "${BLUE}Enter the desired storage account name: ${NC} ")" -i "${default_storage_account_name}" STORAGE_ACCOUNT_NAME

read -e -p "$(echo -e "${BLUE}Enter the desired export_name: ${NC} ")" -i "${default_export_name}" export_name

read -e -p "$(echo -e "${BLUE}Enter the desired directory field (for the export): ${NC} ")" -i "${default_directory_field}" directory_field

# Variables for the storage account etc.
from=$(date -u +%Y-%m-%dT%H:%M:%SZ)
to="2050-02-01T00:00:00+00:00"

# Resource Group
if ! (az group list --query "[?location=='eastus']" --query [].name -o tsv | grep -q "${resource_group}$"); then
   az group create --name ${resource_group} --location eastus > /dev/null
fi

# Display the selected resource group
echo -e "Resource group: ${GREEN} ${resource_group} ${NC}"
#----------------------------------------------------------------------------------------------------------


#-------------------------------
### STORAGE CHECKS AND CREATION
#-------------------------------
echo
echo -e "${BLUE}STORAGE CHECKS AND CREATION.${NC} Please, wait..."

az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $resource_group --allow-blob-public-access false  >/dev/null 2>&1 || exit 1
while [ "$(az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $resource_group --query provisioningState -o tsv || echo Failed)" != "Succeeded" ]
do
  sleep 5
done 2>/dev/null

az storage container create --account-name $STORAGE_ACCOUNT_NAME --name $CONTAINER_NAME  >/dev/null 2>&1 || exit 1
while [ $(az storage container exists --account-name $STORAGE_ACCOUNT_NAME --name $CONTAINER_NAME --query exists -o tsv) != "true" ]
do
  sleep 5
done 2>/dev/null

# get the storage account key
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group $resource_group --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv) 2>&1 >/dev/null
echo -e "${GREEN}Done${NC}"
echo "---"

#-------------------------------
### EXPORT CREATION AND EXECUTION
#-------------------------------

echo
echo -e "${BLUE}EXPORT CREATION AND EXECUTION${NC}. Please, wait..."

# create the export

set -x
ba_scope="/providers/Microsoft.Billing/billingAccounts/${billing_account_id}"

az costmanagement export create --name $export_name --type ActualCost \
 --scope "${ba_scope}" \
 --storage-account-id /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resource_group/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME \
 --storage-container $CONTAINER_NAME --timeframe MonthToDate --recurrence Daily \
 --recurrence-period from="$from" to="$to" \
 --schedule-status Active --storage-directory ${directory_field} > /dev/null
set +x

#-------------------------------
### APP REGISTRATION
#------------------------------
echo -e "${BLUE}APP REGISTRATION${NC}"

if (az ad app list --query [].displayName --output tsv | grep -q "${appregname}$" ); then
  clientid=$(az ad app list --query "[].{displayName:displayName, appId:appId}" --output tsv | tr '\t' ' ' | grep "${appregname} " | awk '{print$2}')
  #clientsecret=$(az ad app credential list --id $clientid --query [].keyId --output tsv)
else
  clientid=$(az ad app create --display-name $appregname --query appId --output tsv 2>/dev/null)
fi

clientsecretname=mycert2
clientsecretduration=2
if ! clientsecret=$(az ad app credential reset --id $clientid --append --display-name $clientsecretname --years $clientsecretduration --query password --output tsv); then
    echo -e "${RED}App: $appregname exists. You do not have permition to it or other restriction${NC}"
    exit 1
fi

objectid=$(az ad app show --id $clientid --query objectId --output tsv 2>/dev/null)

#echo "clientid $clientid"
#echo "objectid $objectid"
#echo "clientsecret $clientsecret"

###AAD service principal
spid=$(az ad sp create --id $clientid --query id --output tsv 2>/dev/null || az ad sp show --id $clientid --query id --output tsv 2>/dev/null)
#echo "spid $spid"



# assign the role_name role to the service principal and check if the role was successfully assigned
role_name="Monitoring Reader"

echo "---"
echo -e "${BLUE}Assign the ${role_name} role to the service principal and check if the role was successfully assigned${NC}"


# assign the role_name role to the service principal
az role assignment create --assignee $spid --role "$role_name" --scope /subscriptions/$SUBSCRIPTION_ID >/dev/null 2>&1 || exit 1

# check if the role was successfully assigned
role_assignment=$(az role assignment list --assignee $spid --query "[?roleDefinitionName=='$role_name'].{Name:name, Principal:principalName, Role:roleDefinitionName}" --output json 2>/dev/null)

if [ -z "$role_assignment" ]
then
    echo -e "${RED}$role_name role was not assigned successfully.${NC}"
else
    echo -e "${GREEN}$role_name role was assigned successfully.${NC}"
    echo "Role assignment details:"
    echo "$role_assignment"
fi


# assign the Storage Blob Data Reader role to the service principal and check if the role was successfully assigned
role_name="Storage Blob Data Reader"

echo "---"
echo -e "${BLUE}Assign the ${role_name} role to the service principal and check if the role was successfully assigned${NC}"


# assign the role_name role to the service principal
az role assignment create --assignee $spid --role "$role_name" --scope /subscriptions/$SUBSCRIPTION_ID >/dev/null 2>&1 || exit 1

# check if the role was successfully assigned
role_assignment=$(az role assignment list --assignee $spid --query "[?roleDefinitionName=='$role_name'].{Name:name, Principal:principalName, Role:roleDefinitionName}" --output json 2>/dev/null)

if [ -z "$role_assignment" ]
then
    echo -e "${RED}$role_name role was not assigned successfully.${NC}"
else
    echo -e "${GREEN}$role_name role was assigned successfully.${NC}"
    echo "Role assignment details:"
    echo "$role_assignment"
fi
# Get Storage Account ID
STORAGE_ACCOUNT_ID=$(az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $selected_rg --query 'id' -o tsv 2>/dev/null)

# Construct Container ID
CONTAINER_ID="$STORAGE_ACCOUNT_ID/blobServices/default/containers/$CONTAINER_NAME"

#-----------------------------------------
resource_group_name=$resource_group
storage_account_name=$STORAGE_ACCOUNT_NAME
container_name=$CONTAINER_NAME

# Get the role definition ID for "Storage Blob Data Reader"
role_id=$(az role definition list --name "Storage Blob Data Reader" --query "[].name" -o tsv 2>/dev/null)

# Now use the role definition ID in your az role assignment list command
#az role assignment list --include-inherited \
#  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resource_group_name/providers/Microsoft.Storage/storageAccounts/$storage_account_name/blobContainers/$container_name \
#  --role $role_id


echo ""
echo -e  "${BLUE}----------------------------------- ( Your details are as follows ) --------------------------------------${NC}"
echo " ________________________________________________________________________________________________________ "
echo ""
echo " Please copy the values below and paste them during the creation of your account on an adult's website"
echo ""
echo ""
echo -e " ${GREEN}Your AppName is:${NC} $appregname"
echo ""
echo -e " ${GREEN}Your client ID is:${NC} $clientid"
echo ""
echo -e " ${GREEN}STORAGE_ACCOUNT_NAME:${NC} $STORAGE_ACCOUNT_NAME"
echo ""
echo -e " ${GREEN}CONTAINER_NAME:${NC} $CONTAINER_NAME"
echo ""
echo -e " ${GREEN}Your Clientsecret:${NC} $clientsecret"
echo ""
tanetID=$(az account show --query tenantId --output tsv)
echo -e " ${GREEN}Your tenant ID:${NC} $tanetID"
