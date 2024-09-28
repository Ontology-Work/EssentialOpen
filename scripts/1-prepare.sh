#!/bin/bash

# Function to display error messages
function error_exit {
    echo "$1" 1>&2
    exit 1
}

# Function to generate a random password of 8 characters
generate_password() {
    openssl rand -base64 6
}

get_or_generate_password() {
    local key=$1
    local file="secret.txt"

    if [ ! -f "$file" ]; then
        touch "$file"
    fi

    if grep -q "^${key}=" "$file"; then
        awk -F'=' -v key="$key" '$1 == key {print substr($0, index($0,$2))}' "$file"
    else
        local password=$(generate_password)
        echo "${key}=${password}" >> "$file"
        echo "$password"
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
            perl -i -pe "s/^${key}=.*/${key}=${value}/" "$file"
        fi
    else
        echo "${key}=${!key}" >> "$file"
    fi
}

unzip_file() {
    local zip_file=$1
    local extract_dir=$2

    mkdir -p "$extract_dir"
    if [ -z "$(ls -A "$extract_dir")" ]; then
        echo "Unzipping $zip_file to $extract_dir..."
        unzip -o -q "$zip_file" -d "$extract_dir" || { echo "Failed to unzip $zip_file"; exit 1; }
        echo "File unzipped successfully."
    else
        echo "$extract_dir is not empty, skipping unzip."
    fi
}

echo

echo "1. Download files."
while IFS=' ' read -r DOWNLOAD_DIR URL; do
    FILENAME=$(basename "$URL")
    if [ ! -f "$DOWNLOAD_DIR/$FILENAME" ]; then
        echo "Downloading $FILENAME to $DOWNLOAD_DIR..."
        mkdir -p "$DOWNLOAD_DIR" # Cria o diretório se não existir
        curl -L -o "$DOWNLOAD_DIR/$FILENAME" "$URL" || error_exit "Failed to download $FILENAME"
    else
        echo "$FILENAME already exists in $DOWNLOAD_DIR, skipping download."
    fi
done < downloads.txt
echo

echo "2. Extract repository and server files."
unzip_file "protege/downloads/essential_baseline_v6_19.zip" "EssentialAM/Repository"
unzip_file "protege/downloads/metaproject.zip" "EssentialAM/server"
echo

echo "3. Define Database Passwords"
MYSQL_USER=essential
MYSQL_DATABASE=essentialdb
MYSQL_PASSWORD=$(get_or_generate_password "MYSQL_PASSWORD")
MYSQL_ROOT_PASSWORD=$(get_or_generate_password "MYSQL_ROOT_PASSWORD")
get_or_add_env_var "MYSQL_USER"
get_or_add_env_var "MYSQL_DATABASE"
get_or_add_env_var "MYSQL_PASSWORD"
get_or_add_env_var "MYSQL_ROOT_PASSWORD"
perl -0777 -i -pe "s|\(name \"password\"\)\n\t\(string_value \".*?\"\)\)|\(name \"password\"\)\n\t\(string_value \"$MYSQL_PASSWORD\"\)\)|g" EssentialAM/Repository/essential_baseline_6_19.pprj
echo

echo "4. Extract Viewer data"
unzip_file "viewer/downloads/essential_viewer_61910.war" "EssentialAM/essential_viewer"
PUBLISHER_PASSWORD=$(get_or_generate_password "PUBLISHER_PASSWORD")
perl -pi -e "s|username=\"publisher\" password=\".*?\"|username=\"publisher\" password=\"$PUBLISHER_PASSWORD\"|g" viewer/tomcat-users.xml
cp viewer/web.xml EssentialAM/essential_viewer/WEB-INF/web.xml
cp viewer/core_header.xsl EssentialAM/essential_viewer/common/core_header.xsl
echo "PUBLISHER_PASSWORD=${PUBLISHER_PASSWORD}"
echo "Yo'll need this password to updade viewer from Protégé"
echo
