#!/bin/bash
set -euo pipefail

# Check if the wp-content directory is empty, if so, download WordPress
if [ ! -f /var/www/html/wp-config.php ]; then
  echo "Downloading WordPress..."
  curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
  tar -xzf /tmp/wordpress.tar.gz -C /tmp

  # Use rsync to copy files
  rsync -av --ignore-existing /tmp/wordpress/ /var/www/html/
fi

# Set correct permissions for the WordPress files
chown -R www-data:www-data /var/www/html

# Execute the original entrypoint of the WordPress image
exec docker-entrypoint.sh apache2-foreground