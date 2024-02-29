#!/usr/bin/env bash

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
  exit
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
############################################
#-------------------------------
### RESOURCE GROUP SELECTION OR CREATION
#-------------------------------
############################################

# Get the list of resource groups
resource_groups=($(az group list --query '[].name' -o tsv))

# Calculate the number of resource groups
num_groups=${#resource_groups[@]}

# Display the resource groups in two columns
echo "Select a resource group or create a new one:"
printf "%2d) %-50s\n" 1 "Create new resource group"
for ((i=0; i < num_groups; i+=2)); do
  index1=$((i+2))
  index2=$((i+3))
  printf "%2d) %-50s%2d) %-50s\n" $index1 "${resource_groups[i]}" $index2 "${resource_groups[i+1]}"
done

# Prompt the user to select or create a resource group
while true; do
  read -p "#? " rg_selection
  if [[ $rg_selection =~ ^[0-9]+$ ]] && [ $rg_selection -ge 1 ] && [ $rg_selection -le $((num_groups+1)) ]; then
    break
  else
    echo -e "${RED}Invalid selection. Please enter a valid number.${NC}"
  fi
done

if [ $rg_selection -eq 1 ]; then
  read -p "Enter the name of the new resource group: " new_rg_name
  az group create --name $new_rg_name --location eastus > /dev/null
  selected_rg=$new_rg_name
else
  selected_rg=${resource_groups[rg_selection-2]}
fi

# Display the selected resource group
echo -e "You selected resource group: ${GREEN} $selected_rg ${NC}"
#----------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------

# Function to check storage account name validity
check_storage_account_name() {
    local name=$1
    local length=${#name}

    # Check length
    if [[ $length -lt 3 ]] || [[ $length -gt 24 ]]; then
        echo "Storage account name must be between 3 and 24 characters in length."
        return 1
    fi

    # Check if contains only numbers and lower-case letters
    if [[ $name =~ [^a-z0-9] ]]; then
        echo "Storage account name must use numbers and lower-case letters only."
        return 1
    fi

    return 0
}

# Variables for the storage account etc.
LOCATION="eastus"
CONTAINER_NAME="anodotcontainer"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
from=$(date -u +%Y-%m-%dT%H:%M:%SZ)
to=$(date -u -d "+1 month" +%Y-%m-%dT%H:%M:%SZ)
export_name="DemoExport"
STORAGE_ACCOUNT_KEY=""

# Generate storage account name and check validity
while true; do
    STORAGE_ACCOUNT_NAME="anodotblob$(shuf -i 100000-999999 -n 1)"
    if check_storage_account_name $STORAGE_ACCOUNT_NAME; then
        break
    else
        echo "Invalid storage account name generated. Regenerating..."
    fi
done

#-------------------------------
### STORAGE CHECKS AND CREATION
#-------------------------------
echo
echo -e "${BLUE}STORAGE CHECKS AND CREATION.${NC} Please, wait..."
#loading 45 &
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $selected_rg --allow-blob-public-access true >/dev/null 2>&1 || exit 1
while [ "$(az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $selected_rg --query provisioningState -o tsv || echo Failed)" != "Succeeded" ]
do
  sleep 5
done 2>/dev/null

az storage container create --account-name $STORAGE_ACCOUNT_NAME --name $CONTAINER_NAME  >/dev/null 2>&1 || exit 1
while [ $(az storage container exists --account-name $STORAGE_ACCOUNT_NAME --name $CONTAINER_NAME --query exists -o tsv) != "true" ]
do
  sleep 5
done 2>/dev/null

# get the storage account key
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group $selected_rg --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv) 2>&1 >/dev/null
echo -e "${GREEN}Done${NC}"
echo "---"

#-------------------------------
### EXPORT CREATION AND EXECUTION
#-------------------------------

echo
echo -e "${BLUE}EXPORT CREATION AND EXECUTION${NC}. Please, wait..."


# create the export
# ActualCost, AmortizedCost

az costmanagement export create --name $export_name --type ActualCost \
--scope "subscriptions/$SUBSCRIPTION_ID" \
--storage-account-id /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$selected_rg/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME \
--storage-container $CONTAINER_NAME --timeframe MonthToDate --recurrence Daily \
--recurrence-period from="$from" to="$to" \
--schedule-status Active --storage-directory demodirectory > /dev/null

# trigger the export via HTTP request
endpoint="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.CostManagement/exports/$export_name/run?api-version=2021-10-01"
request_body='{ "commandName": "Microsoft_Azure_CostManagement.ACM.Exports.run" }'
access_token=$(az account get-access-token --query accessToken -o tsv)

http_response=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" -H "Accept: application/json" -d "$request_body" $endpoint)

# trigger the export via az cli
az storage blob list --account-name $STORAGE_ACCOUNT_NAME --account-key $STORAGE_ACCOUNT_KEY --container-name $CONTAINER_NAME --output table

# Debug STORAGE_ACCOUNT_KEY
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group $selected_rg --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
#echo "Storage Account Key: $STORAGE_ACCOUNT_KEY"

# Wait for the export file to be generated
echo "Waiting for the export file to be generated..."
sleep_duration=60
max_attempts=30
attempt_counter=0
file_found=false

print_progress_bar() {
  local filled=""
  local empty=""
  local progress_bar_width=50

  for ((i = 0; i < $1; i++)); do
    filled+="="
  done
  for ((i = 0; i < $((progress_bar_width - $1)); i++)); do
    empty+=" "
  done

  printf "|%-*s|" "$progress_bar_width" "$filled$empty"
}

function loading() {
  local duration=$1
  local sleep_duration=1
  local max_iterations=$((duration))
  local iteration=0

  while [ $iteration -lt $max_iterations ]; do
    printf "\r%s" "$(print_progress_bar $((iteration * 50 / max_iterations)))"
    sleep $sleep_duration
    iteration=$((iteration + 1))
  done

  printf "\n"
}

while [ $attempt_counter -lt $max_attempts ] && [ "$file_found" = false ]
do
  # List the blobs in the container
  blobs_list=$(az storage blob list --account-name $STORAGE_ACCOUNT_NAME --account-key $STORAGE_ACCOUNT_KEY --container-name $CONTAINER_NAME --query '[].name' -o tsv)

  # Check if any of the blobs match the exported file pattern
  for blob_name in $blobs_list; do
    if [[ $blob_name == demodirectory/* ]]; then
      file_found=true
      echo -e "\nExported file found: $blob_name"
      break
    fi
  done

  if [ "$file_found" = false ]; then
    attempt_counter=$((attempt_counter + 1))
    loading 1
  fi
done

if [ "$file_found" = false ]; then
  echo -e "${RED}The exported file was not found in the container after $max_attempts attempts. Please check the export process or try again later.${NC}"
  loading 2
else
  echo -e "${GREEN}The exported file has been successfully generated and is available in the container.${NC}"
  loading 2
fi
echo "---"

 # Re-enable logging after storage account creatio

#-------------------------------
### APP REGISTRATION
#------------------------------


echo -e "${BLUE}APP REGISTRATION${NC}"
# Define the maximum number of attempts
max_attempts=3
attempt_counter=0

# Loop until a valid choice is entered or the maximum attempts are reached
while [ $attempt_counter -lt $max_attempts ]; do
  # Prompt the user for the application name
  echo "Select an option for the application name:"
  echo "1. Use default name (AnodotRegApp)"
  echo "2. Enter custom name"

  # Read user input
  read -p "Enter your choice (1 or 2): " choice

  # Process the choice and set the appregname variable accordingly
  case $choice in
      1)
          appregname="AnodotRegApp"
          break
          ;;
      2)
          read -p "Enter the custom application name: " custom_app_name
          appregname="$custom_app_name"
          break
          ;;
      *)
          echo -e "${RED}Invalid choice. Please try again.${NC}"
          attempt_counter=$((attempt_counter + 1))
          ;;
  esac
done



# Check if the maximum attempts are reached
if [ $attempt_counter -ge $max_attempts ]; then
  echo -e "${RED}Exceeded maximum attempts. Exiting.${NC}"
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)

#create appregname="anodotregapp"

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


# Set the length of the loading bar
BAR_LENGTH=50

# Define the print_progress_bar function
print_progress_bar() {
  local filled=""
  local empty=""
  local progress_bar_width=$BAR_LENGTH
  local percentage=$((100 * $1 / progress_bar_width))
  local custom_text="Anodot-AI: control your costs"

  for ((i = 0; i < $1; i++)); do
    filled+="█"
  done

  for ((i = 0; i < $((progress_bar_width - $1)); i++)); do
    empty+="░"
  done

  printf "%s |%-*s| %3d%%" "$custom_text" "$progress_bar_width" "$filled$empty" "$percentage"
}

# Define the loading function
function loading() {
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



# assign the role_name role to the service principal and check if the role was successfully assigned
role_name="Monitoring Reader"

echo "---"
echo -e "${BLUE}Assign the ${role_name} role to the service principal and check if the role was successfully assigned${NC}"


# assign the role_name role to the service principal
az role assignment create --assignee $spid --role "$role_name" --scope /subscriptions/$SUBSCRIPTION_ID >/dev/null 2>&1 || exit 1

# check if the role was successfully assigned
role_assignment=$(az role assignment list --assignee $spid --query "[?roleDefinitionName=='$role_name'].{Name:name, Principal:principalName, Role:roleDefinitionName}" --output json 2>/dev/null)

#loading 2

if [ -z "$role_assignment" ]
then
    echo -e "${RED}$role_name role was not assigned successfully.${NC}"
else
    echo -e "${GREEN}$role_name role was assigned successfully.${NC}"
    echo "Role assignment details:"
    echo "$role_assignment"
fi

# Set the length of the loading bar
BAR_LENGTH=50

# Define the print_progress_bar function
print_progress_bar() {
  local filled=""
  local empty=""
  local progress_bar_width=$BAR_LENGTH
  local percentage=$((100 * $1 / progress_bar_width))
  local custom_text="Anodot-AI: control your costs"

  for ((i = 0; i < $1; i++)); do
    filled+="█"
  done

  for ((i = 0; i < $((progress_bar_width - $1)); i++)); do
    empty+="░"
  done

  printf "%s |%-*s| %3d%%" "$custom_text" "$progress_bar_width" "$filled$empty" "$percentage"
}

# Define the loading function
function loading() {
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

# assign the Storage Blob Data Reader role to the service principal and check if the role was successfully assigned
role_name="Storage Blob Data Reader"

echo "---"
echo -e "${BLUE}Assign the ${role_name} role to the service principal and check if the role was successfully assigned${NC}"


# assign the role_name role to the service principal
az role assignment create --assignee $spid --role "$role_name" --scope /subscriptions/$SUBSCRIPTION_ID >/dev/null 2>&1 || exit 1

# check if the role was successfully assigned
role_assignment=$(az role assignment list --assignee $spid --query "[?roleDefinitionName=='$role_name'].{Name:name, Principal:principalName, Role:roleDefinitionName}" --output json 2>/dev/null)
#loading 2

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
resource_group_name=$selected_rg
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
