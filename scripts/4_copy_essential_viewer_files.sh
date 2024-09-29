#!/bin/bash

# Function to display error messages
function error_exit {
    echo "$1" 1>&2
    exit 1
}

get_env_var(){
    local key=$1
    local file="env_file.env"
    local value=${!key}

    if [ ! -f "$file" ]; then
        touch "$file"
    fi

    if grep -q "^${key}=" "$file"; then
        current_value=$(awk -F'=' -v key="$key" '$1 == key {print substr($0, index($0,$2))}' "$file")
        echo $current_value
    fi
}

echo 
echo "If you continue, the script will copy all the contents of the "
echo "EssentialAM/essential_viewer folder to the File Share Viewer in Azure," 
echo "this will take a while."
echo
echo "Do you want to proceed? (y/n): "
read answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Proceeding with copy..."
    # Check if az CLI is installed
    if ! command -v az &> /dev/null
    then
        echo "Azure CLI is not installed. Please install it to proceed."
        exit 1
    fi

    STG_ACCESS_KEY=$(get_env_var "STG_ACCESS_KEY")
    az storage file upload-batch --destination essentialviewer \
        --source ./EssentialAM/essential_viewer/ \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STG_ACCESS_KEY

fi

    

