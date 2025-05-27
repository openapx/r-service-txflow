#! /bin/bash

#
# Deploy ngnx proxy
#
#
#


# -- constants
API_PORT=7749

# -- generate/rotate certificate

echo "-- generate self-signed certificates"

# - certificate home
OPENAPX_SSL_HOME=/etc/ssl

mkdir -p  ${OPENAPX_SSL_HOME} $(dirname ${OPENAPX_SSL_CERT}) $(dirname ${OPENAPX_SSL_KEY})

# - certificate files

OPENAPX_SSL_CERT=$(mktemp --tmpdir=${OPENAPX_SSL_HOME}/certs cert-openapx-service-XXXXXXXXXXXXXXXXX --suffix=.pem)
OPENAPX_SSL_KEY=$(mktemp --tmpdir=${OPENAPX_SSL_HOME}/private key-openapx-service-XXXXXXXXXXXXXXXXX --suffix=.pem)

# - generate cert

openssl req -x509 -newkey rsa:4096 \
        -keyout ${OPENAPX_SSL_KEY} \
        -out ${OPENAPX_SSL_CERT} \
        -sha256 -days 3650 -nodes \
        -subj "/C=XX/ST=XX/L=Interwebs/O=openapx/OU=services/CN=service" 2>/dev/null
        
ln -s ${OPENAPX_SSL_CERT} ${OPENAPX_SSL_HOME}/certs/cert-openapx-service.pem
ln -s ${OPENAPX_SSL_KEY} ${OPENAPX_SSL_HOME}/private/key-openapx-service.pem
        

# -- configure nginx with cert

echo "-- enable nginx SSL on port 443"
echo "   - reverse proxy defined for /api"
echo "   - default internal API port set to ${API_PORT}"

# - update nginx.conf

NGINX_CONF=/etc/nginx/nginx.conf

cat << EOF > ${NGINX_CONF}
     
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
        # multi_accept on;
}
      
      
http {


upstream backend {

   # -- at one listening backend R session
   server 127.0.0.1:7749;
   
   # -- do not edit
   #    managed by /entrypoint.sh
   # -- entrypoint: add additional worker ports --


}

server {
    listen              80;
    server_name         www.example.com;
    
    location /api {
      proxy_pass http://backend;
    }
}

server {
    listen              443 ssl;
    server_name         www.example.com;
    ssl_certificate     ${OPENAPX_SSL_HOME}/certs/cert-openapx-service.pem;
    ssl_certificate_key ${OPENAPX_SSL_HOME}/private/key-openapx-service.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    
    location /api {
      proxy_pass http://backend;
    }

}

}
      
EOF

echo "-- nginx proxy configuration complete"
