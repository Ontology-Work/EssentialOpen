#!/bin/bash

LOG_FILE="execution.log"

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

get_or_add_env_var() {
    local key=$1
    local file="env_file.env"
    local value=${!key}

    if [ ! -f "$file" ]; then
        touch "$file"
    fi

    if grep -q "^${key}=" "$file"; then
        current_value=$(awk -F'=' -v key="$key" '$1 == key {print substr($0, index($0,$2))}' "$file")
        if [ "$current_value" != "$value" ]; then
            perl -i -pe "s|^${key}=.*|${key}=${value}|" "$file"
        fi
    else
        echo "${key}=${!key}" >> "$file"
    fi
}

echo 
echo "Floowing resources will be created on Azure in location ${LOCATION}:"
echo
echo "   Container instance: ${CONTAINER_INSTANCE}"
echo "   Database for MySQL: ${MYSQL_NAME}"
echo
echo "Do you want to proceed? (y/n): "
read answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Proceeding with the deployment..."
    # Check if az CLI is installed
    if ! command -v az &> /dev/null
    then
        echo "Azure CLI is not installed. Please install it to proceed."
        exit 1
    fi
    
    MYSQL_DEPLOYED=$(get_env_var "MYSQL_DEPLOYED")
    MYSQL_USER=$(get_env_var "MYSQL_USER")
    MYSQL_PASSWORD=$(get_env_var "MYSQL_PASSWORD")
    MYSQL_DATABASE=$(get_env_var "MYSQL_DATABASE")
    DB_SERVER=$(get_env_var "DB_SERVER")


    STG_ACCESS_KEY=$(get_env_var "STG_ACCESS_KEY")
    if [ -z "$STG_ACCESS_KEY" ]; then
        STG_ACCESS_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT --query "[0].value" --output tsv)
        get_or_add_env_var "STG_ACCESS_KEY"
    fi

    if [ -z "$MYSQL_DEPLOYED" ]; then
        az mysql flexible-server create --name $MYSQL_NAME \
            --resource-group $RESOURCE_GROUP --location $LOCATION \
            --admin-user $MYSQL_USER --admin-password $MYSQL_PASSWORD \
            --sku-name Standard_B1s

        az mysql flexible-server db create --resource-group $RESOURCE_GROUP \
            --server-name $MYSQL_NAME --database-name $MYSQL_DATABASE//
        
        az mysql flexible-server firewall-rule create \
            --resource-group $RESOURCE_GROUP \
            --name $MYSQL_NAME --rule-name AllowAllAzureIPs \
            --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0


        eval "docker run --name mysqlcli --rm -v ./initdb:/dump mysql:9.0 sh -c 'gunzip -c /dump/essentialdb.sql.gz | mysql -h $DB_SERVER -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE'"

        if [ -z "$DB_SERVER" ]; then
            DB_SERVER=$(az mysql flexible-server show --name $MYSQL_NAME --resource-group $RESOURCE_GROUP --query "fullyQualifiedDomainName" --output tsv)
            get_or_add_env_var "DB_SERVER"
        fi

        MYSQL_DEPLOYED=1
        get_or_add_env_var "MYSQL_DEPLOYED"
    fi
    
    az storage share-rm create --resource-group $RESOURCE_GROUP \
        --storage-account $STORAGE_ACCOUNT --name repository
    az storage share-rm create --resource-group $RESOURCE_GROUP \
        --storage-account $STORAGE_ACCOUNT --name server

    perl -i -pe "s|essential-db|$DB_SERVER|g" EssentialAM/Repository/essential_baseline_6_19.pprj

    az storage file upload-batch --destination repository \
        --source ./EssentialAM/Repository --account-name $STORAGE_ACCOUNT \
        --account-key $STG_ACCESS_KEY
    
    perl -i -pe "s|$DB_SERVER|essential-db|g" EssentialAM/Repository/essential_baseline_6_19.pprj

    az storage file upload-batch --destination server \
        --source ./EssentialAM/server --account-name $STORAGE_ACCOUNT \
        --account-key $STG_ACCESS_KEY
    
    az acr login --name $CONTAINER_REGISTRY
    docker compose build protege
    docker tag protege $CONTAINER_REGISTRY.azurecr.io/essential-protege:latest
    docker push $CONTAINER_REGISTRY.azurecr.io/essential-protege:latest

    ACR_USERNAME=$(get_env_var "ACR_USERNAME")
    if [ -z "$ACR_USERNAME" ]; then
        ACR_USERNAME=$CONTAINER_REGISTRY
        get_or_add_env_var "ACR_USERNAME"
    fi

    ACR_PASSWORD=$(get_env_var "ACR_PASSWORD")
    if [ -z "$ACR_PASSWORD" ]; then
        ACR_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY --query "passwords[0].value" --output tsv)
        get_or_add_env_var "ACR_PASSWORD"
    fi

    FQDN=$CONTAINER_INSTANCE.$LOCATION.azurecontainer.io

    cp protege/protege-template.yaml protege/protege.yaml
    perl -i -pe "s|<LOCATION>|${LOCATION}|" protege.yaml
    perl -i -pe "s|<CONTAINER_INSTANCE>|${CONTAINER_INSTANCE}|" protege/protege.yaml
    perl -i -pe "s|<CONTAINER_REGISTRY>|${CONTAINER_REGISTRY}|" protege/protege.yaml
    perl -i -pe "s|<ACR_PASSWORD>|${ACR_PASSWORD}|" protege/protege.yaml
    perl -i -pe "s|<STORAGE_ACCOUNT>|${STORAGE_ACCOUNT}|" protege/protege.yaml
    perl -i -pe "s|<STG_ACCESS_KEY>|${STG_ACCESS_KEY}|" protege/protege.yaml

    az container create --resource-group $RESOURCE_GROUP --file protege/protege.yaml
    
    echo "Protégé Server: $CONTAINER_REGISTRY.azurecr.io"
fi

# az container attach --resource-group rg-essential-dishful --name protege-essential-dishful
# az container exec --resource-group rg-essential-dishful --name protege-essential-dishful --exec-command bash

