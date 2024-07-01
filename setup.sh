#!/bin/bash

# Function to generate self-signed certificates
generate_self_signed_certs() {
  echo "Generating self-signed SSL certificates..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout certs/nginx-selfsigned.key -out certs/nginx-selfsigned.crt -config openssl.cnf
}

# Function to generate Let's Encrypt certificates using Certbot
generate_certbot_certs() {
  echo "Generating Let's Encrypt SSL certificates with Certbot..."
  docker run -it --rm \
    -v "$(pwd)/certs:/etc/letsencrypt" \
    -v "$(pwd)/certs:/var/lib/letsencrypt" \
    -p 80:80 \
    certbot/certbot certonly --standalone -d $SITE_URL --non-interactive --agree-tos -m your-email@example.com

  if [ ! -f certs/live/$SITE_URL/fullchain.pem ] || [ ! -f certs/live/$SITE_URL/privkey.pem ]; then
    echo "Error: Let's Encrypt certificate generation failed."
    exit 1
  fi
}

# Function to add self-signed certificates to the trusted store
add_self_signed_cert_to_trusted() {
  echo "Adding self-signed SSL certificates to the trusted store..."
  case "$OSTYPE" in
    darwin*)  # macOS
      sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/nginx-selfsigned.crt
      ;;
    linux*)
      sudo cp certs/nginx-selfsigned.crt /usr/local/share/ca-certificates/nginx-selfsigned.crt
      sudo update-ca-certificates
      ;;
    msys*|cygwin*|win32*)  # Windows
      certutil -addstore -f "Root" certs\\nginx-selfsigned.crt
      ;;
    *)
      echo "Unsupported OS for adding trusted certificates. Please add the certificate manually."
      ;;
  esac
}

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

# Function to ensure correct permissions for wordpress_data & mariadb_data directory
ensure_permissions() {
  echo "Ensuring correct permissions for wordpress_data directory..."
  sudo chown -R www-data:www-data wordpress_data
  sudo chmod -R 755 wordpress_data

  echo "Ensuring correct permissions for mariadb_data directory..."
  sudo chmod -R 755 mariadb_data
}

# Function to clean up resources in case of failure
cleanup_on_failure() {
  echo "Cleaning up resources due to failure..."
  docker-compose down
  docker volume rm ${APP_NAME}_wordpress_data
  docker volume rm ${APP_NAME}_mariadb_data
  docker network rm ${APP_NAME}_wp_network
  remove_self_signed_cert_from_trusted
  echo "Installation failed."
  exit 1
}

# Load environment variables from .env file
set -a
. ./.env
set +a

# Check if APP_NAME and SITE_URL are set
if [ -z "$APP_NAME" ] || [ -z "$SITE_URL" ]; then
  echo "Error: APP_NAME and SITE_URL must be set in the .env file."
  echo "Please set these variables and run the script again."
  exit 1
fi

# Create certs directory if it doesn't exist
mkdir -p certs

# Create wordpress_data directory if it doesn't exist
mkdir -p wordpress_data

# Create mariadb_data directory if it doesn't exist
mkdir -p mariadb_data

# Ensure correct permissions for wordpress_data directory
ensure_permissions

# Trap errors and ensure cleanup on failure
trap cleanup_on_failure ERR

# Prompt user for certificate generation method
echo "Select the certificate generation method:"
echo "1) Self-signed certificates"
echo "2) Let's Encrypt certificates with Certbot"
read -p "Enter the number (1 or 2): " CERT_METHOD

case $CERT_METHOD in
  1)
    if [ ! -f certs/nginx-selfsigned.crt ] || [ ! -f certs/nginx-selfsigned.key ]; then
      generate_self_signed_certs
    else
      echo "Self-signed SSL certificates already exist. Skipping generation."
    fi
    add_self_signed_cert_to_trusted
    ;;
  2)
    generate_certbot_certs
    ;;
  *)
    echo "Invalid option. Please select 1 or 2."
    exit 1
    ;;
esac

# Generate instance-specific SQL initialization script
cp mariadb-init/init.sql.template mariadb-init/init.sql
sed -i "" "s/\${MYSQL_DATABASE}/$MYSQL_DATABASE/g" mariadb-init/init.sql
sed -i "" "s/\${MYSQL_USER}/$MYSQL_USER/g" mariadb-init/init.sql
sed -i "" "s/\${MYSQL_PASSWORD}/$MYSQL_PASSWORD/g" mariadb-init/init.sql

# Ensure entrypoint.sh is executable
chmod +x nginx/entrypoint.sh

# Build and start the Docker containers
echo "Building and starting Docker containers..."
docker-compose up -d --build

echo "Installation complete. Your site should be accessible at https://$SITE_URL"