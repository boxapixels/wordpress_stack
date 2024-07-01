FROM wordpress:latest

# Set environment variables
ENV WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST}
ENV WORDPRESS_DB_USER=${WORDPRESS_DB_USER}
ENV WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
ENV WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}

# Install rsync
RUN apt-get update && apt-get install -y rsync && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script
COPY wp-entrypoint.sh /usr/local/bin/

# Copy the Apache configuration file
COPY apache.conf /etc/apache2/conf-available/servername.conf

# Enable the Apache configuration file
RUN a2enconf servername

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/wp-entrypoint.sh

# Override the default command with the entrypoint script
ENTRYPOINT ["wp-entrypoint.sh"]