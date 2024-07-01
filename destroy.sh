#!/bin/bash

# Load environment variables from .env file
set -a
. ./.env
set +a

# Check if APP_NAME is set
if [ -z "$APP_NAME" ]; then
  echo "Error: APP_NAME must be set in the .env file."
  echo "Please set this variable and run the script again."
  exit 1
fi

# Function to remove self-signed certificates from the trusted store
remove_self_signed_cert_from_trusted() {
  echo "Removing self-signed SSL certificates from the trusted store..."
  case "$OSTYPE" in
    darwin*)  # macOS
      sudo security delete-certificate -c "localhost"
      ;;
    linux*)
      sudo rm -f /usr/local/share/ca-certificates/nginx-selfsigned.crt
      sudo update-ca-certificates --fresh
      ;;
    msys*|cygwin*|win32*)  # Windows
      certutil -delstore "Root" localhost
      ;;
    *)
      echo "Unsupported OS for removing trusted certificates. Please remove the certificate manually."
      ;;
  esac
}

# Prompt for confirmation
echo "!!!!!!!!! DANGER !!!!!!!!!!"
echo "This script will stop and remove all Docker containers, volumes, and networks for $APP_NAME."
echo "It will also remove any self-signed SSL certificates from the trusted store and any instance-specific initialization scripts."
echo " "
read -p "Are you sure you want to stop and remove all containers, volumes, and networks for $APP_NAME? (y/N): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cleanup aborted."
  exit 0
fi

# Stop and remove Docker containers
echo "Stopping and removing Docker containers..."
docker-compose down

# Remove Docker volumes
echo "Removing Docker volumes..."
docker volume rm ${APP_NAME}_wordpress_data
docker volume rm ${APP_NAME}_mariadb_data

# Remove Docker network
echo "Removing Docker network..."
docker network rm ${APP_NAME}_network

# remove the docker-compose.yml file
if [ -f docker-compose.yml ]; then
  echo "Removing docker-compose.yml file..."
  rm docker-compose.yml
fi


# Optionally, remove the certs directory if you want to clean up certificates
read -p "Do you want to remove the certs directory? (y/N): " REMOVE_CERTS
if [ "$REMOVE_CERTS" = "y" ] || [ "$REMOVE_CERTS" = "Y" ]; then
  echo "Removing certs directory..."
  rm -rf certs
fi

# Remove the self-signed certificates from the trusted store
remove_self_signed_cert_from_trusted

# Remove instance-specific initialization script
if [ -f mariadb-init/init.sql ]; then
  echo "Removing instance-specific initialization script..."
  rm mariadb-init/init.sql
fi

# Optionally remove wordpress_data directory
read -p "Do you want to remove the wordpress_data directory? (y/N): " REMOVE_WORDPRESS_DATA
if [ "$REMOVE_WORDPRESS_DATA" = "y" ] || [ "$REMOVE_WORDPRESS_DATA" = "Y" ]; then
  echo "Removing wordpress_data directory..."
  rm -rf ${APP_NAME}_wordpress_data
fi

# Optionally remove mariadb_data directory
read -p "Do you want to remove the mariadb_data directory? (y/N): " REMOVE_MARIADB_DATA
if [ "$REMOVE_MARIADB_DATA" = "y" ] || [ "$REMOVE_MARIADB_DATA" = "Y" ]; then
  echo "Removing mariadb_data directory..."
  rm -rf ${APP_NAME}_mariadb_data
fi

echo "Cleanup complete."