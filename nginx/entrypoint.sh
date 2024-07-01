#!/bin/sh

# Check if Let's Encrypt certificates exist
if [ -f /etc/nginx/certs/live/$SITE_URL/fullchain.pem ] && [ -f /etc/nginx/certs/live/$SITE_URL/privkey.pem ]; then
  echo "Using Let's Encrypt certificates."
  export SSL_CERT="/etc/nginx/certs/live/$SITE_URL/fullchain.pem"
  export SSL_CERT_KEY="/etc/nginx/certs/live/$SITE_URL/privkey.pem"
else
  echo "Using self-signed certificates."
  export SSL_CERT="/etc/nginx/certs/nginx-selfsigned.crt"
  export SSL_CERT_KEY="/etc/nginx/certs/nginx-selfsigned.key"
fi

# Replace placeholders in the nginx template with actual values
envsubst '${SITE_URL} ${SSL_CERT} ${SSL_CERT_KEY}' < /etc/nginx/nginx.template > /etc/nginx/nginx.conf

# Start nginx
nginx -g 'daemon off;'